from rest_framework import serializers
from django.contrib.auth.models import User
from .models import MiniApp, AppVersion, UserProfile

class UserProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    
    class Meta:
        model = UserProfile
        fields = ['username', 'email', 'avatar', 'bio']

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

class MiniAppSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)
    latest_version = serializers.SerializerMethodField()
    download_url = serializers.SerializerMethodField()

    class Meta:
        model = MiniApp
        fields = ['id', 'bundle_id', 'author_name', 'name', 'description', 'icon', 'latest_version', 'download_url', 'created_at']
        read_only_fields = ['id', 'author_name', 'latest_version', 'download_url', 'created_at']

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

