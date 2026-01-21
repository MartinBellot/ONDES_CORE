from django.contrib import admin
from .models import (
    UserKeyPair, Conversation, ConversationMember, 
    Message, MessageReceipt, TypingIndicator
)


@admin.register(UserKeyPair)
class UserKeyPairAdmin(admin.ModelAdmin):
    list_display = ('user', 'version', 'created_at', 'rotated_at')
    search_fields = ('user__username',)
    readonly_fields = ('created_at', 'rotated_at')


class ConversationMemberInline(admin.TabularInline):
    model = ConversationMember
    extra = 0
    readonly_fields = ('joined_at',)


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ('uuid', 'conversation_type', 'name', 'created_by', 'created_at', 'member_count')
    list_filter = ('conversation_type', 'created_at')
    search_fields = ('uuid', 'name', 'created_by__username')
    inlines = [ConversationMemberInline]
    readonly_fields = ('uuid', 'created_at', 'updated_at')
    
    def member_count(self, obj):
        return obj.members.count()
    member_count.short_description = "Membres"


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('uuid', 'conversation', 'sender', 'message_type', 'created_at', 'is_deleted')
    list_filter = ('message_type', 'is_deleted', 'created_at')
    search_fields = ('uuid', 'sender__username')
    readonly_fields = ('uuid', 'created_at', 'edited_at')
    
    # Note: Le contenu est chiffré, on ne peut pas le lire
    fieldsets = (
        ('Informations', {
            'fields': ('uuid', 'conversation', 'sender', 'message_type', 'reply_to')
        }),
        ('Contenu E2EE', {
            'fields': ('encrypted_content', 'encrypted_metadata', 'encrypted_file'),
            'description': '⚠️ Le contenu est chiffré de bout en bout. Le serveur ne peut pas le déchiffrer.'
        }),
        ('État', {
            'fields': ('is_deleted', 'created_at', 'edited_at')
        }),
    )


@admin.register(MessageReceipt)
class MessageReceiptAdmin(admin.ModelAdmin):
    list_display = ('message', 'user', 'receipt_type', 'timestamp')
    list_filter = ('receipt_type', 'timestamp')


@admin.register(TypingIndicator)
class TypingIndicatorAdmin(admin.ModelAdmin):
    list_display = ('conversation', 'user', 'started_at')
