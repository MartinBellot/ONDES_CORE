from rest_framework import serializers
from django.contrib.auth.models import User
from .models import MiniApp, AppVersion, UserProfile, Category, AppScreenshot, AppReview


class UserProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = UserProfile
        fields = ['username', 'avatar', 'bio']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('username', 'password', 'email')

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            password=validated_data['password'],
            email=validated_data.get('email', '')
        )
        UserProfile.objects.create(user=user)
        return user


class CategorySerializer(serializers.ModelSerializer):
    """Serializer pour les catégories"""
    apps_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ['id', 'slug', 'name', 'icon', 'color', 'order', 'apps_count']
    
    def get_apps_count(self, obj):
        return obj.apps.count()


class AppScreenshotSerializer(serializers.ModelSerializer):
    """Serializer pour les screenshots"""
    
    class Meta:
        model = AppScreenshot
        fields = ['id', 'image', 'device_type', 'order', 'caption']


class ReviewAuthorSerializer(serializers.ModelSerializer):
    """Auteur d'un avis (simplifié)"""
    avatar = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'username', 'avatar']
    
    def get_avatar(self, obj):
        try:
            if obj.profile and obj.profile.avatar:
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(obj.profile.avatar.url)
                return obj.profile.avatar.url
        except:
            pass
        return None


class AppReviewSerializer(serializers.ModelSerializer):
    """Serializer pour les avis utilisateur"""
    user = ReviewAuthorSerializer(read_only=True)
    
    class Meta:
        model = AppReview
        fields = [
            'id', 'user', 'rating', 'title', 'content',
            'developer_response', 'developer_response_date',
            'app_version', 'helpful_count', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'developer_response', 'developer_response_date', 'helpful_count', 'created_at', 'updated_at']


class AppReviewCreateSerializer(serializers.ModelSerializer):
    """Serializer pour créer/modifier un avis"""
    
    class Meta:
        model = AppReview
        fields = ['rating', 'title', 'content', 'app_version']


class DeveloperResponseSerializer(serializers.Serializer):
    """Serializer pour réponse développeur"""
    response = serializers.CharField(max_length=2000)


class MiniAppListSerializer(serializers.ModelSerializer):
    """Serializer léger pour les listes (Store principal)"""
    author_name = serializers.CharField(source='author.username', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_slug = serializers.CharField(source='category.slug', read_only=True)
    latest_version = serializers.SerializerMethodField()
    download_url = serializers.SerializerMethodField()
    average_rating = serializers.FloatField(read_only=True)
    ratings_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = MiniApp
        fields = [
            'id', 'bundle_id', 'name', 'description', 'icon', 
            'author_name', 'category_name', 'category_slug',
            'age_rating', 'latest_version', 'download_url', 'average_rating', 'ratings_count',
            'downloads_count', 'featured', 'source_type', 'genesis_project_id',
            'is_published', 'created_at'
        ]

    def get_latest_version(self, obj):
        version = obj.versions.filter(is_active=True).first()
        return version.version_number if version else "0.0.0"

    def get_download_url(self, obj):
        version = obj.versions.filter(is_active=True).first()
        if version and version.zip_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(version.zip_file.url)
            return version.zip_file.url
        return None


class MiniAppDetailSerializer(serializers.ModelSerializer):
    """Serializer complet pour la page de détail"""
    author_name = serializers.CharField(source='author.username', read_only=True)
    author_id = serializers.IntegerField(source='author.id', read_only=True)
    category = CategorySerializer(read_only=True)
    screenshots = AppScreenshotSerializer(many=True, read_only=True)
    reviews = serializers.SerializerMethodField()
    latest_version = serializers.SerializerMethodField()
    download_url = serializers.SerializerMethodField()
    average_rating = serializers.FloatField(read_only=True)
    ratings_count = serializers.IntegerField(read_only=True)
    size_formatted = serializers.CharField(read_only=True)
    user_review = serializers.SerializerMethodField()
    rating_distribution = serializers.SerializerMethodField()

    class Meta:
        model = MiniApp
        fields = [
            'id', 'bundle_id', 'name', 'description', 'full_description', 'whats_new',
            'icon', 'banner', 'author_name', 'author_id',
            'category', 'tags', 'age_rating',
            'size_bytes', 'size_formatted', 'languages',
            'privacy_url', 'support_url', 'website_url',
            'downloads_count', 'featured',
            'latest_version', 'download_url',
            'average_rating', 'ratings_count', 'rating_distribution',
            'screenshots', 'reviews', 'user_review',
            'source_type', 'genesis_project_id', 'is_published',
            'created_at', 'updated_at'
        ]

    def get_latest_version(self, obj):
        version = obj.versions.filter(is_active=True).first()
        return version.version_number if version else "0.0.0"

    def get_download_url(self, obj):
        version = obj.versions.filter(is_active=True).first()
        if version and version.zip_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(version.zip_file.url)
            return version.zip_file.url
        return None
    
    def get_reviews(self, obj):
        """Retourne les 10 derniers avis"""
        reviews = obj.reviews.all()[:10]
        return AppReviewSerializer(reviews, many=True, context=self.context).data
    
    def get_user_review(self, obj):
        """Retourne l'avis de l'utilisateur connecté si existant"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            try:
                review = obj.reviews.get(user=request.user)
                return AppReviewSerializer(review, context=self.context).data
            except AppReview.DoesNotExist:
                pass
        return None
    
    def get_rating_distribution(self, obj):
        """Distribution des notes (1-5 étoiles)"""
        distribution = {}
        total = obj.reviews.count()
        for i in range(1, 6):
            count = obj.reviews.filter(rating=i).count()
            distribution[str(i)] = {
                'count': count,
                'percentage': round((count / total * 100) if total > 0 else 0, 1)
            }
        return distribution


class MiniAppSerializer(serializers.ModelSerializer):
    """Serializer pour création/édition (Dev Studio)"""
    author_name = serializers.CharField(source='author.username', read_only=True)
    latest_version = serializers.SerializerMethodField()
    download_url = serializers.SerializerMethodField()
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(), 
        source='category', 
        required=False, 
        allow_null=True,
        write_only=True
    )
    # Return full category object for Dev Studio to pre-fill dropdown
    category = CategorySerializer(read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    average_rating = serializers.FloatField(read_only=True)
    ratings_count = serializers.IntegerField(read_only=True)
    # Include screenshots for Dev Studio visualization
    screenshots = AppScreenshotSerializer(many=True, read_only=True)

    class Meta:
        model = MiniApp
        fields = [
            'id', 'bundle_id', 'author_name', 'name', 'description', 'full_description',
            'whats_new', 'icon', 'banner', 'category_id', 'category', 'category_name', 'tags',
            'age_rating', 'languages', 'privacy_url', 'support_url', 'website_url',
            'latest_version', 'download_url', 'average_rating', 'ratings_count',
            'downloads_count', 'source_type', 'genesis_project_id', 'is_published', 'created_at', 'screenshots'
        ]
        read_only_fields = ['id', 'author_name', 'latest_version', 'download_url', 'downloads_count', 'created_at', 'average_rating', 'ratings_count', 'screenshots']

    def get_latest_version(self, obj):
        version = obj.versions.filter(is_active=True).first()
        return version.version_number if version else "0.0.0"

    def get_download_url(self, obj):
        version = obj.versions.filter(is_active=True).first()
        if version and version.zip_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(version.zip_file.url)
            return version.zip_file.url
        return None


class AppVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppVersion
        fields = ['id', 'version_number', 'release_notes', 'created_at', 'is_active']

