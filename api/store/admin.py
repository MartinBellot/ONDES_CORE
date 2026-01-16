from django.contrib import admin
from django.utils.html import format_html
from .models import MiniApp, AppVersion, UserProfile


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'bio', 'avatar_preview')
    search_fields = ('user__username', 'user__email', 'bio')
    readonly_fields = ('avatar_preview',)
    
    def avatar_preview(self, obj):
        if obj.avatar:
            return format_html('<img src="{}" width="50" height="50" style="border-radius: 50%;" />', obj.avatar.url)
        return "No avatar"
    avatar_preview.short_description = "Avatar"


class VersionInline(admin.TabularInline):
    model = AppVersion
    extra = 1


@admin.register(MiniApp)
class MiniAppAdmin(admin.ModelAdmin):
    list_display = ('name', 'bundle_id', 'author', 'created_at', 'versions_count')
    list_filter = ('created_at', 'author')
    search_fields = ('name', 'bundle_id', 'description', 'author__username')
    inlines = [VersionInline]
    
    def versions_count(self, obj):
        return obj.versions.count()
    versions_count.short_description = "Versions"

