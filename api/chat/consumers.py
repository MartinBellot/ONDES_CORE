"""
Ondes Chat - Django Channels Consumers pour WebSocket temps réel

Architecture:
1. ChatConsumer: Gère les connexions WebSocket et le routage des messages
2. Tous les messages transitent chiffrés E2EE
3. Le serveur ne fait que relayer, il ne peut pas lire le contenu
"""

import json
import logging
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.authtoken.models import Token

from .models import (
    Conversation, ConversationMember, Message, 
    MessageReceipt, TypingIndicator, UserKeyPair
)

logger = logging.getLogger(__name__)


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """
    Consumer WebSocket pour le chat E2EE en temps réel.
    
    Actions supportées:
    - send_message: Envoyer un message chiffré
    - typing: Indicateur de frappe
    - read_receipt: Accusé de lecture
    - join_conversation: Rejoindre une conversation
    - leave_conversation: Quitter une conversation
    - get_messages: Récupérer l'historique
    - edit_message: Modifier un message
    - delete_message: Supprimer un message
    """
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.user = None
        self.conversations = set()  # UUIDs des conversations actives
    
    async def connect(self):
        """Connexion WebSocket avec authentification par token"""
        # Récupérer le token depuis les query params
        query_string = self.scope.get('query_string', b'').decode()
        params = dict(param.split('=') for param in query_string.split('&') if '=' in param)
        token_key = params.get('token')
        
        if not token_key:
            logger.warning("Chat connection rejected: No token provided")
            await self.close(code=4001)
            return
        
        # Valider le token
        self.user = await self.get_user_from_token(token_key)
        if not self.user:
            logger.warning(f"Chat connection rejected: Invalid token")
            await self.close(code=4001)
            return
        
        # Accepter la connexion
        await self.accept()
        
        # Rejoindre le groupe personnel de l'utilisateur pour les notifications
        await self.channel_layer.group_add(
            f"user_{self.user.id}",
            self.channel_name
        )
        
        # Charger et rejoindre toutes les conversations de l'utilisateur
        conversations = await self.get_user_conversations()
        for conv_uuid in conversations:
            self.conversations.add(conv_uuid)
            await self.channel_layer.group_add(
                f"chat_{conv_uuid}",
                self.channel_name
            )
        
        logger.info(f"Chat connected: {self.user.username} (joined {len(conversations)} conversations)")
        
        # Envoyer confirmation
        await self.send_json({
            'type': 'connection_established',
            'user_id': self.user.id,
            'username': self.user.username,
            'conversations_joined': list(conversations)
        })
    
    async def disconnect(self, code):
        """Déconnexion propre"""
        if self.user:
            # Quitter le groupe personnel
            await self.channel_layer.group_discard(
                f"user_{self.user.id}",
                self.channel_name
            )
            
            # Quitter toutes les conversations
            for conv_uuid in self.conversations:
                await self.channel_layer.group_discard(
                    f"chat_{conv_uuid}",
                    self.channel_name
                )
            
            # Nettoyer les indicateurs de frappe
            await self.clear_typing_indicators()
            
            logger.info(f"Chat disconnected: {self.user.username}")
    
    async def receive_json(self, content):
        """Recevoir et router les messages JSON"""
        action = content.get('action')
        data = content.get('data', {})
        
        if not action:
            await self.send_error("Missing 'action' field")
            return
        
        # Router vers le handler approprié
        handlers = {
            'send_message': self.handle_send_message,
            'typing': self.handle_typing,
            'read_receipt': self.handle_read_receipt,
            'delivered_receipt': self.handle_delivered_receipt,
            'join_conversation': self.handle_join_conversation,
            'get_messages': self.handle_get_messages,
            'edit_message': self.handle_edit_message,
            'delete_message': self.handle_delete_message,
            'get_public_keys': self.handle_get_public_keys,
        }
        
        handler = handlers.get(action)
        if handler:
            try:
                await handler(data)
            except Exception as e:
                logger.error(f"Error handling {action}: {e}")
                await self.send_error(f"Error: {str(e)}")
        else:
            await self.send_error(f"Unknown action: {action}")
    
    # ========== MESSAGE HANDLERS ==========
    
    async def handle_send_message(self, data):
        """Envoyer un message chiffré"""
        conv_uuid = data.get('conversation_uuid')
        encrypted_content = data.get('encrypted_content')
        message_type = data.get('message_type', 'text')
        encrypted_metadata = data.get('encrypted_metadata', '')
        reply_to_uuid = data.get('reply_to_uuid')
        
        if not conv_uuid or not encrypted_content:
            await self.send_error("conversation_uuid and encrypted_content required")
            return
        
        # Vérifier l'appartenance à la conversation et rejoindre si nécessaire
        if conv_uuid not in self.conversations:
            is_member = await self.check_membership(conv_uuid)
            if not is_member:
                await self.send_error("Not a member of this conversation")
                return
            # Rejoindre le groupe WebSocket pour cette conversation
            self.conversations.add(conv_uuid)
            await self.channel_layer.group_add(
                f"chat_{conv_uuid}",
                self.channel_name
            )
            logger.info(f"User {self.user.username} joined chat_{conv_uuid}")
        
        # Créer le message
        message = await self.create_message(
            conv_uuid=conv_uuid,
            encrypted_content=encrypted_content,
            message_type=message_type,
            encrypted_metadata=encrypted_metadata,
            reply_to_uuid=reply_to_uuid
        )
        
        if not message:
            await self.send_error("Failed to create message")
            return
        
        # Diffuser le message à tous les membres de la conversation
        await self.channel_layer.group_send(
            f"chat_{conv_uuid}",
            {
                'type': 'chat_message',
                'message': {
                    'uuid': str(message['uuid']),
                    'conversation_uuid': conv_uuid,
                    'sender_id': self.user.id,
                    'sender_username': self.user.username,
                    'message_type': message_type,
                    'encrypted_content': encrypted_content,
                    'encrypted_metadata': encrypted_metadata,
                    'reply_to_uuid': reply_to_uuid,
                    'created_at': message['created_at'],
                }
            }
        )
    
    async def handle_typing(self, data):
        """Gérer l'indicateur de frappe"""
        conv_uuid = data.get('conversation_uuid')
        is_typing = data.get('is_typing', False)
        
        if not conv_uuid:
            return
        
        if conv_uuid not in self.conversations:
            return
        
        await self.update_typing_indicator(conv_uuid, is_typing)
        
        # Diffuser à la conversation
        await self.channel_layer.group_send(
            f"chat_{conv_uuid}",
            {
                'type': 'typing_indicator',
                'data': {
                    'conversation_uuid': conv_uuid,
                    'user_id': self.user.id,
                    'username': self.user.username,
                    'is_typing': is_typing,
                }
            }
        )
    
    async def handle_read_receipt(self, data):
        """Marquer des messages comme lus"""
        message_uuids = data.get('message_uuids', [])
        
        if not message_uuids:
            return
        
        receipts = await self.mark_messages_read(message_uuids)
        
        # Notifier les expéditeurs
        for receipt in receipts:
            await self.channel_layer.group_send(
                f"user_{receipt['sender_id']}",
                {
                    'type': 'receipt_update',
                    'data': {
                        'message_uuid': receipt['message_uuid'],
                        'user_id': self.user.id,
                        'receipt_type': 'read',
                        'timestamp': receipt['timestamp'],
                    }
                }
            )
    
    async def handle_delivered_receipt(self, data):
        """Marquer des messages comme délivrés"""
        message_uuids = data.get('message_uuids', [])
        
        if not message_uuids:
            return
        
        await self.mark_messages_delivered(message_uuids)
    
    async def handle_join_conversation(self, data):
        """Rejoindre une conversation spécifique"""
        conv_uuid = data.get('conversation_uuid')
        encrypted_key = data.get('encrypted_conversation_key')
        
        if not conv_uuid:
            await self.send_error("conversation_uuid required")
            return
        
        is_member = await self.check_membership(conv_uuid)
        if not is_member:
            await self.send_error("Not a member of this conversation")
            return
        
        if conv_uuid not in self.conversations:
            self.conversations.add(conv_uuid)
            await self.channel_layer.group_add(
                f"chat_{conv_uuid}",
                self.channel_name
            )
        
        # Récupérer les infos de la conversation
        conv_info = await self.get_conversation_info(conv_uuid)
        
        await self.send_json({
            'type': 'conversation_joined',
            'conversation': conv_info
        })
    
    async def handle_get_messages(self, data):
        """Récupérer l'historique des messages"""
        conv_uuid = data.get('conversation_uuid')
        limit = min(data.get('limit', 50), 100)
        before_uuid = data.get('before_uuid')
        
        if not conv_uuid:
            await self.send_error("conversation_uuid required")
            return
        
        if conv_uuid not in self.conversations:
            is_member = await self.check_membership(conv_uuid)
            if not is_member:
                await self.send_error("Not a member of this conversation")
                return
        
        messages = await self.get_messages(conv_uuid, limit, before_uuid)
        
        await self.send_json({
            'type': 'messages_history',
            'conversation_uuid': conv_uuid,
            'messages': messages
        })
    
    async def handle_edit_message(self, data):
        """Modifier un message existant"""
        message_uuid = data.get('message_uuid')
        encrypted_content = data.get('encrypted_content')
        
        if not message_uuid or not encrypted_content:
            await self.send_error("message_uuid and encrypted_content required")
            return
        
        result = await self.edit_message(message_uuid, encrypted_content)
        
        if not result:
            await self.send_error("Failed to edit message")
            return
        
        # Diffuser la modification
        await self.channel_layer.group_send(
            f"chat_{result['conversation_uuid']}",
            {
                'type': 'message_edited',
                'data': {
                    'message_uuid': message_uuid,
                    'encrypted_content': encrypted_content,
                    'edited_at': result['edited_at'],
                }
            }
        )
    
    async def handle_delete_message(self, data):
        """Supprimer un message"""
        message_uuid = data.get('message_uuid')
        
        if not message_uuid:
            await self.send_error("message_uuid required")
            return
        
        result = await self.delete_message(message_uuid)
        
        if not result:
            await self.send_error("Failed to delete message")
            return
        
        # Diffuser la suppression
        await self.channel_layer.group_send(
            f"chat_{result['conversation_uuid']}",
            {
                'type': 'message_deleted',
                'data': {
                    'message_uuid': message_uuid,
                }
            }
        )
    
    async def handle_get_public_keys(self, data):
        """Récupérer les clés publiques des utilisateurs"""
        user_ids = data.get('user_ids', [])
        
        if not user_ids:
            await self.send_error("user_ids required")
            return
        
        keys = await self.get_public_keys(user_ids)
        
        await self.send_json({
            'type': 'public_keys',
            'keys': keys
        })
    
    # ========== BROADCAST HANDLERS ==========
    
    async def chat_message(self, event):
        """Recevoir un message de la conversation"""
        await self.send_json({
            'type': 'new_message',
            'message': event['message']
        })
    
    async def typing_indicator(self, event):
        """Recevoir un indicateur de frappe"""
        # Ne pas s'envoyer à soi-même
        if event['data']['user_id'] != self.user.id:
            await self.send_json({
                'type': 'typing',
                'data': event['data']
            })
    
    async def receipt_update(self, event):
        """Recevoir une mise à jour d'accusé de réception"""
        await self.send_json({
            'type': 'receipt',
            'data': event['data']
        })
    
    async def message_edited(self, event):
        """Recevoir une modification de message"""
        await self.send_json({
            'type': 'message_edited',
            'data': event['data']
        })
    
    async def message_deleted(self, event):
        """Recevoir une suppression de message"""
        await self.send_json({
            'type': 'message_deleted',
            'data': event['data']
        })
    
    async def conversation_update(self, event):
        """Recevoir une mise à jour de conversation"""
        await self.send_json({
            'type': 'conversation_update',
            'data': event['data']
        })
    
    # ========== DATABASE OPERATIONS ==========
    
    @database_sync_to_async
    def get_user_from_token(self, token_key):
        """Valider un token et retourner l'utilisateur"""
        try:
            token = Token.objects.select_related('user').get(key=token_key)
            return token.user
        except Token.DoesNotExist:
            return None
    
    @database_sync_to_async
    def get_user_conversations(self):
        """Récupérer toutes les conversations de l'utilisateur"""
        memberships = ConversationMember.objects.filter(
            user=self.user
        ).select_related('conversation')
        return [str(m.conversation.uuid) for m in memberships]
    
    @database_sync_to_async
    def check_membership(self, conv_uuid):
        """Vérifier si l'utilisateur est membre de la conversation"""
        return ConversationMember.objects.filter(
            conversation__uuid=conv_uuid,
            user=self.user
        ).exists()
    
    @database_sync_to_async
    def create_message(self, conv_uuid, encrypted_content, message_type, 
                       encrypted_metadata, reply_to_uuid):
        """Créer un nouveau message"""
        try:
            conversation = Conversation.objects.get(uuid=conv_uuid)
            
            reply_to = None
            if reply_to_uuid:
                try:
                    reply_to = Message.objects.get(uuid=reply_to_uuid)
                except Message.DoesNotExist:
                    pass
            
            message = Message.objects.create(
                conversation=conversation,
                sender=self.user,
                message_type=message_type,
                encrypted_content=encrypted_content,
                encrypted_metadata=encrypted_metadata,
                reply_to=reply_to
            )
            
            # Mettre à jour la conversation
            conversation.updated_at = timezone.now()
            conversation.save(update_fields=['updated_at'])
            
            return {
                'uuid': str(message.uuid),
                'created_at': message.created_at.isoformat()
            }
        except Exception as e:
            logger.error(f"Error creating message: {e}")
            return None
    
    @database_sync_to_async
    def get_messages(self, conv_uuid, limit, before_uuid):
        """Récupérer les messages d'une conversation"""
        queryset = Message.objects.filter(
            conversation__uuid=conv_uuid
        ).select_related('sender', 'reply_to')
        
        if before_uuid:
            try:
                before_msg = Message.objects.get(uuid=before_uuid)
                queryset = queryset.filter(created_at__lt=before_msg.created_at)
            except Message.DoesNotExist:
                pass
        
        messages = queryset.order_by('-created_at')[:limit]
        
        return [{
            'uuid': str(m.uuid),
            'sender_id': m.sender.id if m.sender else None,
            'sender_username': m.sender.username if m.sender else 'System',
            'message_type': m.message_type,
            'encrypted_content': m.encrypted_content if not m.is_deleted else '',
            'encrypted_metadata': m.encrypted_metadata,
            'reply_to_uuid': str(m.reply_to.uuid) if m.reply_to else None,
            'created_at': m.created_at.isoformat(),
            'edited_at': m.edited_at.isoformat() if m.edited_at else None,
            'is_deleted': m.is_deleted,
        } for m in reversed(list(messages))]
    
    @database_sync_to_async
    def get_conversation_info(self, conv_uuid):
        """Récupérer les infos d'une conversation"""
        try:
            conv = Conversation.objects.get(uuid=conv_uuid)
            members = ConversationMember.objects.filter(
                conversation=conv
            ).select_related('user')
            
            return {
                'uuid': str(conv.uuid),
                'name': conv.name,
                'conversation_type': conv.conversation_type,
                'avatar': conv.avatar.url if conv.avatar else None,
                'members': [{
                    'user_id': m.user.id,
                    'username': m.user.username,
                    'role': m.role,
                    'encrypted_conversation_key': m.encrypted_conversation_key,
                } for m in members],
                'created_at': conv.created_at.isoformat(),
            }
        except Conversation.DoesNotExist:
            return None
    
    @database_sync_to_async
    def edit_message(self, message_uuid, encrypted_content):
        """Modifier un message"""
        try:
            message = Message.objects.get(uuid=message_uuid, sender=self.user)
            message.encrypted_content = encrypted_content
            message.edited_at = timezone.now()
            message.save(update_fields=['encrypted_content', 'edited_at'])
            
            return {
                'conversation_uuid': str(message.conversation.uuid),
                'edited_at': message.edited_at.isoformat()
            }
        except Message.DoesNotExist:
            return None
    
    @database_sync_to_async
    def delete_message(self, message_uuid):
        """Supprimer un message (soft delete)"""
        try:
            message = Message.objects.get(uuid=message_uuid, sender=self.user)
            conv_uuid = str(message.conversation.uuid)
            message.soft_delete()
            return {'conversation_uuid': conv_uuid}
        except Message.DoesNotExist:
            return None
    
    @database_sync_to_async
    def mark_messages_read(self, message_uuids):
        """Marquer des messages comme lus"""
        receipts = []
        for uuid_str in message_uuids:
            try:
                message = Message.objects.select_related('sender').get(uuid=uuid_str)
                if message.sender and message.sender.id != self.user.id:
                    receipt, created = MessageReceipt.objects.get_or_create(
                        message=message,
                        user=self.user,
                        receipt_type='read',
                        defaults={'timestamp': timezone.now()}
                    )
                    if created:
                        receipts.append({
                            'message_uuid': uuid_str,
                            'sender_id': message.sender.id,
                            'timestamp': receipt.timestamp.isoformat()
                        })
            except Message.DoesNotExist:
                continue
        return receipts
    
    @database_sync_to_async
    def mark_messages_delivered(self, message_uuids):
        """Marquer des messages comme délivrés"""
        for uuid_str in message_uuids:
            try:
                message = Message.objects.get(uuid=uuid_str)
                if message.sender and message.sender.id != self.user.id:
                    MessageReceipt.objects.get_or_create(
                        message=message,
                        user=self.user,
                        receipt_type='delivered',
                        defaults={'timestamp': timezone.now()}
                    )
            except Message.DoesNotExist:
                continue
    
    @database_sync_to_async
    def update_typing_indicator(self, conv_uuid, is_typing):
        """Mettre à jour l'indicateur de frappe"""
        try:
            conv = Conversation.objects.get(uuid=conv_uuid)
            if is_typing:
                TypingIndicator.objects.update_or_create(
                    conversation=conv,
                    user=self.user,
                    defaults={'started_at': timezone.now()}
                )
            else:
                TypingIndicator.objects.filter(
                    conversation=conv,
                    user=self.user
                ).delete()
        except Conversation.DoesNotExist:
            pass
    
    @database_sync_to_async
    def clear_typing_indicators(self):
        """Supprimer tous les indicateurs de frappe de l'utilisateur"""
        TypingIndicator.objects.filter(user=self.user).delete()
    
    @database_sync_to_async
    def get_public_keys(self, user_ids):
        """Récupérer les clés publiques des utilisateurs"""
        keys = UserKeyPair.objects.filter(user_id__in=user_ids)
        return [{
            'user_id': k.user_id,
            'public_key': k.public_key,
            'version': k.version,
        } for k in keys]
    
    # ========== HELPERS ==========
    
    async def send_error(self, message):
        """Envoyer une erreur au client"""
        await self.send_json({
            'type': 'error',
            'message': message
        })
