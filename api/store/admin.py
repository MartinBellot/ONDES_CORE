from django.contrib import admin
from .models import MiniApp, AppVersion, UserProfile

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'bio')

class VersionInline(admin.TabularInline):
    model = AppVersion
    extra = 1

@admin.register(MiniApp)
class MiniAppAdmin(admin.ModelAdmin):
    list_display = ('name', 'bundle_id', 'created_at')
    inlines = [VersionInline]
