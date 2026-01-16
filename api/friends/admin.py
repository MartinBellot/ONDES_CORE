from django.contrib import admin
from django.utils.html import format_html
from .models import Friendship, FriendshipActivity


@admin.register(Friendship)
class FriendshipAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'from_user_link', 'direction_arrow', 'to_user_link', 
        'status_badge', 'created_at', 'accepted_at'
    )
    list_filter = ('status', 'created_at', 'accepted_at')
    search_fields = ('from_user__username', 'to_user__username', 'from_user__email', 'to_user__email')
    readonly_fields = ('created_at', 'updated_at', 'accepted_at')
    date_hierarchy = 'created_at'
    list_per_page = 50
    
    fieldsets = (
        ('Utilisateurs', {
            'fields': ('from_user', 'to_user')
        }),
        ('Statut', {
            'fields': ('status',)
        }),
        ('Dates', {
            'fields': ('created_at', 'updated_at', 'accepted_at'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['accept_friendships', 'reject_friendships', 'delete_friendships']
    
    def from_user_link(self, obj):
        return format_html(
            '<a href="/admin/auth/user/{}/change/">{}</a>',
            obj.from_user.id, obj.from_user.username
        )
    from_user_link.short_description = "De"
    from_user_link.admin_order_field = 'from_user__username'
    
    def to_user_link(self, obj):
        return format_html(
            '<a href="/admin/auth/user/{}/change/">{}</a>',
            obj.to_user.id, obj.to_user.username
        )
    to_user_link.short_description = "Vers"
    to_user_link.admin_order_field = 'to_user__username'
    
    def direction_arrow(self, obj):
        return "→"
    direction_arrow.short_description = ""
    
    def status_badge(self, obj):
        colors = {
            'pending': '#FFA500',
            'accepted': '#28a745',
            'rejected': '#dc3545',
            'blocked': '#6c757d',
        }
        color = colors.get(obj.status, '#6c757d')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 10px; font-size: 11px;">{}</span>',
            color, obj.get_status_display()
        )
    status_badge.short_description = "Statut"
    status_badge.admin_order_field = 'status'
    
    @admin.action(description="✅ Accepter les demandes sélectionnées")
    def accept_friendships(self, request, queryset):
        updated = queryset.filter(status='pending').update(status='accepted')
        self.message_user(request, f"{updated} demande(s) acceptée(s).")
    
    @admin.action(description="❌ Rejeter les demandes sélectionnées")
    def reject_friendships(self, request, queryset):
        updated = queryset.filter(status='pending').update(status='rejected')
        self.message_user(request, f"{updated} demande(s) rejetée(s).")
    
    @admin.action(description="🗑️ Supprimer les amitiés sélectionnées")
    def delete_friendships(self, request, queryset):
        deleted, _ = queryset.delete()
        self.message_user(request, f"{deleted} amitié(s) supprimée(s).")


@admin.register(FriendshipActivity)
class FriendshipActivityAdmin(admin.ModelAdmin):
    list_display = (
        'timestamp', 'actor_link', 'action_badge', 'target_link', 
        'ip_address', 'friendship_link'
    )
    list_filter = ('action', 'timestamp')
    search_fields = ('actor__username', 'target__username', 'ip_address')
    readonly_fields = ('friendship', 'actor', 'target', 'action', 'timestamp', 'ip_address', 'user_agent')
    date_hierarchy = 'timestamp'
    list_per_page = 100
    
    def has_add_permission(self, request):
        return False  # Logs are auto-generated
    
    def has_change_permission(self, request, obj=None):
        return False  # Logs are read-only
    
    def actor_link(self, obj):
        return format_html(
            '<a href="/admin/auth/user/{}/change/">{}</a>',
            obj.actor.id, obj.actor.username
        )
    actor_link.short_description = "Acteur"
    actor_link.admin_order_field = 'actor__username'
    
    def target_link(self, obj):
        return format_html(
            '<a href="/admin/auth/user/{}/change/">{}</a>',
            obj.target.id, obj.target.username
        )
    target_link.short_description = "Cible"
    target_link.admin_order_field = 'target__username'
    
    def action_badge(self, obj):
        colors = {
            'request': '#17a2b8',
            'accept': '#28a745',
            'reject': '#dc3545',
            'block': '#6c757d',
            'unblock': '#ffc107',
            'remove': '#fd7e14',
        }
        color = colors.get(obj.action, '#6c757d')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 2px 8px; border-radius: 8px; font-size: 10px;">{}</span>',
            color, obj.get_action_display()
        )
    action_badge.short_description = "Action"
    action_badge.admin_order_field = 'action'
    
    def friendship_link(self, obj):
        if obj.friendship:
            return format_html(
                '<a href="/admin/friends/friendship/{}/change/">#{}</a>',
                obj.friendship.id, obj.friendship.id
            )
        return "-"
    friendship_link.short_description = "Amitié"
