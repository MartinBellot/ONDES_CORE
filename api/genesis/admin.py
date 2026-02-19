from django.contrib import admin
from .models import GenesisProject, ProjectVersion, ConversationTurn


class ProjectVersionInline(admin.TabularInline):
    model = ProjectVersion
    extra = 0
    readonly_fields = ['version_number', 'change_description', 'created_at']
    fields = ['version_number', 'change_description', 'created_at']


class ConversationTurnInline(admin.TabularInline):
    model = ConversationTurn
    extra = 0
    readonly_fields = ['role', 'content', 'timestamp']
    fields = ['role', 'content', 'timestamp']


@admin.register(GenesisProject)
class GenesisProjectAdmin(admin.ModelAdmin):
    list_display = ['title', 'user', 'is_deployed', 'created_at', 'updated_at']
    list_filter = ['is_deployed', 'created_at']
    search_fields = ['title', 'user__username']
    readonly_fields = ['id', 'created_at', 'updated_at']
    inlines = [ProjectVersionInline, ConversationTurnInline]


@admin.register(ProjectVersion)
class ProjectVersionAdmin(admin.ModelAdmin):
    list_display = ['project', 'version_number', 'change_description', 'created_at']
    list_filter = ['created_at']
    search_fields = ['project__title', 'change_description']
    readonly_fields = ['created_at']


@admin.register(ConversationTurn)
class ConversationTurnAdmin(admin.ModelAdmin):
    list_display = ['project', 'role', 'timestamp']
    list_filter = ['role', 'timestamp']
    search_fields = ['project__title', 'content']
    readonly_fields = ['timestamp']
