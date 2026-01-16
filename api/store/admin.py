from django.contrib import admin
from django.utils.html import format_html
from .models import MiniApp, AppVersion, UserProfile, Category, AppScreenshot, AppReview


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


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug', 'icon', 'color_preview', 'order', 'apps_count')
    list_editable = ('order',)
    ordering = ('order', 'name')
    
    def color_preview(self, obj):
        return format_html(
            '<span style="background-color: {}; padding: 5px 15px; border-radius: 4px; color: white;">{}</span>',
            obj.color, obj.color
        )
    color_preview.short_description = "Couleur"
    
    def apps_count(self, obj):
        return obj.apps.count()
    apps_count.short_description = "Apps"


class VersionInline(admin.TabularInline):
    model = AppVersion
    extra = 0
    readonly_fields = ('created_at',)
    ordering = ('-created_at',)


class ScreenshotInline(admin.TabularInline):
    model = AppScreenshot
    extra = 1
    ordering = ('order',)


class ReviewInline(admin.TabularInline):
    model = AppReview
    extra = 0
    readonly_fields = ('user', 'rating', 'title', 'content', 'created_at', 'helpful_count')
    can_delete = False
    max_num = 5
    ordering = ('-created_at',)


@admin.register(MiniApp)
class MiniAppAdmin(admin.ModelAdmin):
    list_display = ('name', 'bundle_id', 'author', 'category', 'age_rating', 'average_rating_display', 
                    'downloads_count', 'featured', 'created_at')
    list_filter = ('category', 'age_rating', 'featured', 'created_at', 'author')
    list_editable = ('featured',)
    search_fields = ('name', 'bundle_id', 'description', 'author__username', 'tags')
    readonly_fields = ('average_rating_display', 'ratings_count', 'size_formatted', 'downloads_count', 'icon_preview', 'banner_preview')
    inlines = [VersionInline, ScreenshotInline, ReviewInline]
    
    fieldsets = (
        ('Identité', {
            'fields': ('bundle_id', 'name', 'author', 'icon', 'icon_preview')
        }),
        ('Classification', {
            'fields': ('category', 'tags', 'age_rating')
        }),
        ('Description', {
            'fields': ('description', 'full_description', 'whats_new')
        }),
        ('Médias', {
            'fields': ('banner', 'banner_preview')
        }),
        ('Liens', {
            'fields': ('privacy_url', 'support_url', 'website_url'),
            'classes': ('collapse',)
        }),
        ('Métadonnées', {
            'fields': ('languages', 'size_formatted'),
            'classes': ('collapse',)
        }),
        ('Statistiques', {
            'fields': ('downloads_count', 'average_rating_display', 'ratings_count', 'featured', 'featured_order')
        }),
    )
    
    def average_rating_display(self, obj):
        rating = obj.average_rating
        stars = '★' * int(rating) + '☆' * (5 - int(rating))
        return f"{stars} ({rating}/5)"
    average_rating_display.short_description = "Note moyenne"
    
    def icon_preview(self, obj):
        if obj.icon:
            return format_html('<img src="{}" width="60" height="60" style="border-radius: 12px;" />', obj.icon.url)
        return "Aucune icône"
    icon_preview.short_description = "Aperçu icône"
    
    def banner_preview(self, obj):
        if obj.banner:
            return format_html('<img src="{}" width="300" style="border-radius: 8px;" />', obj.banner.url)
        return "Aucune bannière"
    banner_preview.short_description = "Aperçu bannière"


@admin.register(AppReview)
class AppReviewAdmin(admin.ModelAdmin):
    list_display = ('app', 'user', 'rating_stars', 'title', 'helpful_count', 'created_at', 'has_response')
    list_filter = ('rating', 'created_at', 'app')
    search_fields = ('app__name', 'user__username', 'title', 'content')
    readonly_fields = ('app', 'user', 'rating', 'title', 'content', 'app_version', 'created_at', 'helpful_count')
    
    fieldsets = (
        ('Avis', {
            'fields': ('app', 'user', 'rating', 'title', 'content', 'app_version', 'created_at', 'helpful_count')
        }),
        ('Réponse développeur', {
            'fields': ('developer_response', 'developer_response_date')
        }),
    )
    
    def rating_stars(self, obj):
        return '★' * obj.rating + '☆' * (5 - obj.rating)
    rating_stars.short_description = "Note"
    
    def has_response(self, obj):
        return bool(obj.developer_response)
    has_response.boolean = True
    has_response.short_description = "Répondu"

