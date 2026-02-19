from rest_framework import serializers
from .models import GenesisProject, ProjectVersion, ConversationTurn


class ConversationTurnSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConversationTurn
        fields = ['id', 'role', 'content', 'timestamp']


class ProjectVersionSerializer(serializers.ModelSerializer):
    """Full version — includes html_code. Used for single-version detail."""
    class Meta:
        model = ProjectVersion
        fields = ['id', 'version_number', 'html_code', 'change_description', 'created_at']


class ProjectVersionListSerializer(serializers.ModelSerializer):
    """Lightweight version — no html_code. Used in list / project detail."""
    class Meta:
        model = ProjectVersion
        fields = ['id', 'version_number', 'change_description', 'created_at']


class GenesisProjectListSerializer(serializers.ModelSerializer):
    current_version_number = serializers.SerializerMethodField()

    class Meta:
        model = GenesisProject
        fields = ['id', 'title', 'is_deployed', 'created_at', 'updated_at', 'current_version_number']

    def get_current_version_number(self, obj):
        v = obj.current_version
        return v.version_number if v else 0


class GenesisProjectDetailSerializer(serializers.ModelSerializer):
    current_version = ProjectVersionSerializer(read_only=True)
    versions = ProjectVersionListSerializer(many=True, read_only=True)
    conversation = ConversationTurnSerializer(many=True, read_only=True)

    class Meta:
        model = GenesisProject
        fields = ['id', 'title', 'is_deployed', 'created_at', 'updated_at',
                  'current_version', 'versions', 'conversation']
