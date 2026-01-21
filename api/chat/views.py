from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from django.contrib.auth.models import User
from django.db.models import Q
from django.utils import timezone

from .models import (
    UserKeyPair, Conversation, ConversationMember,
    Message, MessageReceipt
)
from .serializers import (
    UserPublicKeySerializer, UserKeyPairCreateSerializer,
    ConversationListSerializer, ConversationCreateSerializer,
    MessageSerializer, MemberSerializer
)


class KeyPairView(APIView):
    """
    API pour gérer les clés E2EE de l'utilisateur.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        """Récupérer sa propre clé publique"""
        try:
            keypair = request.user.chat_keypair
            serializer = UserPublicKeySerializer(keypair)
            return Response(serializer.data)
        except UserKeyPair.DoesNotExist:
            return Response(
                {'error': 'No keypair registered'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    def post(self, request):
        """Enregistrer ou mettre à jour sa clé publique"""
        serializer = UserKeyPairCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        keypair, created = UserKeyPair.objects.update_or_create(
            user=request.user,
            defaults={
                'public_key': serializer.validated_data['public_key'],
                'key_signature': serializer.validated_data.get('key_signature', ''),
            }
        )
        
        if not created:
            keypair.version += 1
            keypair.save(update_fields=['version'])
        
        return Response({
            'success': True,
            'created': created,
            'version': keypair.version,
            'public_key': keypair.public_key,
        })


class PublicKeysView(APIView):
    """
    API pour récupérer les clés publiques d'autres utilisateurs.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        """Récupérer les clés publiques par user IDs"""
        user_ids = request.query_params.get('user_ids', '')
        if not user_ids:
            return Response(
                {'error': 'user_ids parameter required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            ids = [int(x) for x in user_ids.split(',')]
        except ValueError:
            return Response(
                {'error': 'Invalid user_ids format'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        keypairs = UserKeyPair.objects.filter(user_id__in=ids)
        serializer = UserPublicKeySerializer(keypairs, many=True)
        return Response(serializer.data)
    
    def post(self, request):
        """Récupérer les clés publiques (POST pour listes plus longues)"""
        user_ids = request.data.get('user_ids', [])
        if not user_ids:
            return Response(
                {'error': 'user_ids required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        keypairs = UserKeyPair.objects.filter(user_id__in=user_ids)
        serializer = UserPublicKeySerializer(keypairs, many=True)
        return Response(serializer.data)


class ConversationViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour les conversations.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = ConversationListSerializer
    lookup_field = 'uuid'  # Utiliser UUID au lieu de pk
    
    def get_queryset(self):
        """Retourne uniquement les conversations de l'utilisateur"""
        return Conversation.objects.filter(
            members__user=self.request.user
        ).prefetch_related('members', 'members__user').distinct()
    
    def create(self, request):
        """Créer une nouvelle conversation"""
        serializer = ConversationCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        data = serializer.validated_data
        member_ids = data['member_ids']
        encrypted_keys = data['encrypted_keys']
        
        # Vérifier que tous les utilisateurs existent
        users = User.objects.filter(id__in=member_ids)
        if users.count() != len(member_ids):
            return Response(
                {'error': 'Some users not found'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Pour les conversations privées, vérifier qu'il n'en existe pas déjà une
        if data['conversation_type'] == 'private' and len(member_ids) == 1:
            other_user_id = member_ids[0]
            existing = Conversation.objects.filter(
                conversation_type='private',
                members__user=request.user
            ).filter(
                members__user_id=other_user_id
            ).first()
            
            if existing:
                # Retourner la conversation existante
                response_serializer = ConversationListSerializer(
                    existing, 
                    context={'request': request}
                )
                return Response(response_serializer.data)
        
        # Créer la conversation
        conversation = Conversation.objects.create(
            conversation_type=data['conversation_type'],
            name=data.get('name', ''),
            created_by=request.user
        )
        
        # Ajouter le créateur
        my_encrypted_key = encrypted_keys.get(str(request.user.id), '')
        ConversationMember.objects.create(
            conversation=conversation,
            user=request.user,
            role='owner' if data['conversation_type'] == 'group' else 'member',
            encrypted_conversation_key=my_encrypted_key
        )
        
        # Ajouter les autres membres
        for user in users:
            if user.id != request.user.id:
                user_encrypted_key = encrypted_keys.get(str(user.id), '')
                ConversationMember.objects.create(
                    conversation=conversation,
                    user=user,
                    role='member',
                    encrypted_conversation_key=user_encrypted_key
                )
        
        response_serializer = ConversationListSerializer(
            conversation, 
            context={'request': request}
        )
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'])
    def add_member(self, request, uuid=None):
        """Ajouter un membre à un groupe"""
        conversation = self.get_object()
        
        if conversation.conversation_type != 'group':
            return Response(
                {'error': 'Can only add members to groups'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Vérifier que l'utilisateur est admin/owner
        membership = ConversationMember.objects.get(
            conversation=conversation,
            user=request.user
        )
        if membership.role not in ['admin', 'owner']:
            return Response(
                {'error': 'Only admins can add members'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        user_id = request.data.get('user_id')
        encrypted_key = request.data.get('encrypted_conversation_key')
        
        if not user_id or not encrypted_key:
            return Response(
                {'error': 'user_id and encrypted_conversation_key required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        member, created = ConversationMember.objects.get_or_create(
            conversation=conversation,
            user=user,
            defaults={
                'role': 'member',
                'encrypted_conversation_key': encrypted_key
            }
        )
        
        if not created:
            return Response(
                {'error': 'User is already a member'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return Response({
            'success': True,
            'member': MemberSerializer(member).data
        })
    
    @action(detail=True, methods=['post'])
    def remove_member(self, request, uuid=None):
        """Retirer un membre d'un groupe"""
        conversation = self.get_object()
        
        if conversation.conversation_type != 'group':
            return Response(
                {'error': 'Can only remove members from groups'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user_id = request.data.get('user_id')
        
        # Peut se retirer soi-même ou être admin
        if user_id != request.user.id:
            membership = ConversationMember.objects.get(
                conversation=conversation,
                user=request.user
            )
            if membership.role not in ['admin', 'owner']:
                return Response(
                    {'error': 'Only admins can remove members'},
                    status=status.HTTP_403_FORBIDDEN
                )
        
        try:
            member = ConversationMember.objects.get(
                conversation=conversation,
                user_id=user_id
            )
            member.delete()
            return Response({'success': True})
        except ConversationMember.DoesNotExist:
            return Response(
                {'error': 'Member not found'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=True, methods=['post'])
    def mark_read(self, request, uuid=None):
        """Marquer la conversation comme lue"""
        conversation = self.get_object()
        
        last_message = conversation.messages.filter(is_deleted=False).last()
        if last_message:
            membership = ConversationMember.objects.get(
                conversation=conversation,
                user=request.user
            )
            membership.last_read_message = last_message
            membership.save(update_fields=['last_read_message'])
        
        return Response({'success': True})
    
    @action(detail=True, methods=['get'])
    def messages(self, request, uuid=None):
        """Récupérer les messages d'une conversation"""
        conversation = self.get_object()
        
        limit = min(int(request.query_params.get('limit', 50)), 100)
        before_uuid = request.query_params.get('before')
        
        queryset = conversation.messages.filter(is_deleted=False)
        
        if before_uuid:
            try:
                before_msg = Message.objects.get(uuid=before_uuid)
                queryset = queryset.filter(created_at__lt=before_msg.created_at)
            except Message.DoesNotExist:
                pass
        
        messages = queryset.order_by('-created_at')[:limit]
        serializer = MessageSerializer(reversed(list(messages)), many=True)
        
        return Response(serializer.data)


class StartPrivateConversationView(APIView):
    """
    API simplifiée pour démarrer une conversation privée.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """Démarrer ou récupérer une conversation privée"""
        user_id = request.data.get('user_id')
        username = request.data.get('username')
        encrypted_keys = request.data.get('encrypted_keys', {})
        
        if not user_id and not username:
            return Response(
                {'error': 'user_id or username required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            if username:
                other_user = User.objects.get(username=username)
            else:
                other_user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        if other_user.id == request.user.id:
            return Response(
                {'error': 'Cannot start conversation with yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Chercher une conversation existante
        existing = Conversation.objects.filter(
            conversation_type='private',
            members__user=request.user
        ).filter(
            members__user=other_user
        ).first()
        
        if existing:
            serializer = ConversationListSerializer(
                existing,
                context={'request': request}
            )
            return Response({
                'created': False,
                'conversation': serializer.data
            })
        
        # Créer la conversation
        conversation = Conversation.objects.create(
            conversation_type='private',
            created_by=request.user
        )
        
        # Ajouter les membres
        for user in [request.user, other_user]:
            user_key = encrypted_keys.get(str(user.id), '')
            ConversationMember.objects.create(
                conversation=conversation,
                user=user,
                role='member',
                encrypted_conversation_key=user_key
            )
        
        serializer = ConversationListSerializer(
            conversation,
            context={'request': request}
        )
        return Response({
            'created': True,
            'conversation': serializer.data
        }, status=status.HTTP_201_CREATED)
