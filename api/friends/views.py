from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth.models import User
from django.db.models import Q
from store.models import UserProfile
from .models import Friendship, FriendshipActivity
from .serializers import FriendshipSerializer, UserMiniSerializer


def get_client_ip(request):
    """Récupère l'adresse IP du client"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0]
    return request.META.get('REMOTE_ADDR')


def log_friendship_activity(friendship, actor, target, action, request):
    """Log une activité d'amitié"""
    FriendshipActivity.objects.create(
        friendship=friendship,
        actor=actor,
        target=target,
        action=action,
        ip_address=get_client_ip(request),
        user_agent=request.META.get('HTTP_USER_AGENT', '')[:500]
    )


class FriendsListView(APIView):
    """Liste tous les amis de l'utilisateur connecté"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        
        # Récupérer toutes les amitiés acceptées
        friendships = Friendship.objects.filter(
            Q(from_user=user) | Q(to_user=user),
            status='accepted'
        ).select_related('from_user__profile', 'to_user__profile')
        
        friends = []
        for friendship in friendships:
            friend = friendship.to_user if friendship.from_user == user else friendship.from_user
            
            # Avatar URL
            avatar_url = None
            try:
                if friend.profile and friend.profile.avatar:
                    avatar_url = request.build_absolute_uri(friend.profile.avatar.url)
            except UserProfile.DoesNotExist:
                pass
            
            if not avatar_url:
                avatar_url = f"https://api.dicebear.com/7.x/avataaars/png?seed={friend.username}"
            
            friends.append({
                'id': friend.id,
                'username': friend.username,
                'avatar': avatar_url,
                'bio': getattr(friend.profile, 'bio', '') if hasattr(friend, 'profile') else '',
                'friendship_id': friendship.id,
                'friends_since': friendship.accepted_at,
            })
        
        return Response(friends)


class FriendRequestView(APIView):
    """Envoyer une demande d'amitié"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        username = request.data.get('username')
        user_id = request.data.get('user_id')
        
        if not username and not user_id:
            return Response(
                {'error': 'username or user_id required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            if user_id:
                target_user = User.objects.get(id=user_id)
            else:
                target_user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        if target_user == request.user:
            return Response(
                {'error': 'Cannot send friend request to yourself'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Vérifier si une relation existe déjà
        existing = Friendship.objects.filter(
            Q(from_user=request.user, to_user=target_user) |
            Q(from_user=target_user, to_user=request.user)
        ).first()
        
        if existing:
            if existing.status == 'accepted':
                return Response(
                    {'error': 'Already friends'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            elif existing.status == 'pending':
                # Si c'est l'autre personne qui a envoyé la demande, auto-accepter
                if existing.from_user == target_user:
                    existing.accept()
                    log_friendship_activity(existing, request.user, target_user, 'accept', request)
                    return Response({
                        'message': 'Friend request accepted (mutual request)',
                        'friendship': FriendshipSerializer(existing, context={'request': request}).data
                    })
                return Response(
                    {'error': 'Friend request already pending'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            elif existing.status == 'blocked':
                return Response(
                    {'error': 'Cannot send request to this user'}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            elif existing.status == 'rejected':
                # Permettre de renvoyer une demande si rejetée
                existing.status = 'pending'
                existing.from_user = request.user
                existing.to_user = target_user
                existing.save()
                log_friendship_activity(existing, request.user, target_user, 'request', request)
                return Response({
                    'message': 'Friend request sent',
                    'friendship': FriendshipSerializer(existing, context={'request': request}).data
                }, status=status.HTTP_201_CREATED)
        
        # Créer nouvelle demande
        friendship = Friendship.objects.create(
            from_user=request.user,
            to_user=target_user,
            status='pending'
        )
        
        log_friendship_activity(friendship, request.user, target_user, 'request', request)
        
        return Response({
            'message': 'Friend request sent',
            'friendship': FriendshipSerializer(friendship, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)


class PendingRequestsView(APIView):
    """Liste des demandes d'amitié en attente (reçues)"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Demandes reçues
        received = Friendship.objects.filter(
            to_user=request.user,
            status='pending'
        ).select_related('from_user__profile')
        
        return Response({
            'received': FriendshipSerializer(received, many=True, context={'request': request}).data,
            'count': received.count()
        })


class SentRequestsView(APIView):
    """Liste des demandes d'amitié envoyées"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        sent = Friendship.objects.filter(
            from_user=request.user,
            status='pending'
        ).select_related('to_user__profile')
        
        return Response({
            'sent': FriendshipSerializer(sent, many=True, context={'request': request}).data,
            'count': sent.count()
        })


class AcceptFriendRequestView(APIView):
    """Accepter une demande d'amitié"""
    permission_classes = [IsAuthenticated]

    def post(self, request, friendship_id):
        try:
            friendship = Friendship.objects.get(
                id=friendship_id,
                to_user=request.user,
                status='pending'
            )
        except Friendship.DoesNotExist:
            return Response(
                {'error': 'Friend request not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        friendship.accept()
        log_friendship_activity(friendship, request.user, friendship.from_user, 'accept', request)
        
        return Response({
            'message': 'Friend request accepted',
            'friendship': FriendshipSerializer(friendship, context={'request': request}).data
        })


class RejectFriendRequestView(APIView):
    """Refuser une demande d'amitié"""
    permission_classes = [IsAuthenticated]

    def post(self, request, friendship_id):
        try:
            friendship = Friendship.objects.get(
                id=friendship_id,
                to_user=request.user,
                status='pending'
            )
        except Friendship.DoesNotExist:
            return Response(
                {'error': 'Friend request not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        friendship.reject()
        log_friendship_activity(friendship, request.user, friendship.from_user, 'reject', request)
        
        return Response({'message': 'Friend request rejected'})


class BlockUserView(APIView):
    """Bloquer un utilisateur"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user_id = request.data.get('user_id')
        username = request.data.get('username')
        
        if not user_id and not username:
            return Response(
                {'error': 'user_id or username required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            if user_id:
                target_user = User.objects.get(id=user_id)
            else:
                target_user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Trouver ou créer la relation
        friendship = Friendship.objects.filter(
            Q(from_user=request.user, to_user=target_user) |
            Q(from_user=target_user, to_user=request.user)
        ).first()
        
        if friendship:
            friendship.block()
            # S'assurer que from_user est celui qui bloque
            if friendship.from_user != request.user:
                friendship.from_user, friendship.to_user = friendship.to_user, friendship.from_user
                friendship.save()
        else:
            friendship = Friendship.objects.create(
                from_user=request.user,
                to_user=target_user,
                status='blocked'
            )
        
        log_friendship_activity(friendship, request.user, target_user, 'block', request)
        
        return Response({'message': 'User blocked'})


class UnblockUserView(APIView):
    """Débloquer un utilisateur"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user_id = request.data.get('user_id')
        
        if not user_id:
            return Response(
                {'error': 'user_id required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            friendship = Friendship.objects.get(
                from_user=request.user,
                to_user_id=user_id,
                status='blocked'
            )
        except Friendship.DoesNotExist:
            return Response(
                {'error': 'Blocked user not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        target_user = friendship.to_user
        log_friendship_activity(friendship, request.user, target_user, 'unblock', request)
        friendship.delete()
        
        return Response({'message': 'User unblocked'})


class RemoveFriendView(APIView):
    """Supprimer un ami"""
    permission_classes = [IsAuthenticated]

    def post(self, request, friendship_id):
        try:
            friendship = Friendship.objects.get(
                Q(from_user=request.user) | Q(to_user=request.user),
                id=friendship_id,
                status='accepted'
            )
        except Friendship.DoesNotExist:
            return Response(
                {'error': 'Friend not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        target_user = friendship.to_user if friendship.from_user == request.user else friendship.from_user
        log_friendship_activity(friendship, request.user, target_user, 'remove', request)
        friendship.delete()
        
        return Response({'message': 'Friend removed'})


class SearchUsersView(APIView):
    """Rechercher des utilisateurs"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = request.query_params.get('q', '')
        
        if len(query) < 2:
            return Response(
                {'error': 'Query must be at least 2 characters'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        users = User.objects.filter(
            Q(username__icontains=query)
        ).exclude(id=request.user.id)[:20]
        
        # Ajouter le statut d'amitié pour chaque utilisateur
        results = []
        for user in users:
            friendship = Friendship.objects.filter(
                Q(from_user=request.user, to_user=user) |
                Q(from_user=user, to_user=request.user)
            ).first()
            
            user_data = UserMiniSerializer(user, context={'request': request}).data
            user_data['friendship_status'] = friendship.status if friendship else None
            user_data['friendship_id'] = friendship.id if friendship else None
            results.append(user_data)
        
        return Response(results)


class BlockedUsersView(APIView):
    """Liste des utilisateurs bloqués"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        blocked = Friendship.objects.filter(
            from_user=request.user,
            status='blocked'
        ).select_related('to_user__profile')
        
        return Response({
            'blocked': FriendshipSerializer(blocked, many=True, context={'request': request}).data,
            'count': blocked.count()
        })
