from rest_framework import serializers
from .models import GenesisProject, ProjectVersion, ConversationTurn, GenesisQuota


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
    store_app_id = serializers.SerializerMethodField()
    store_app_is_published = serializers.SerializerMethodField()

    class Meta:
        model = GenesisProject
        fields = ['id', 'title', 'is_deployed', 'deployed_version_number',
                  'created_at', 'updated_at', 'current_version_number',
                  'store_app_id', 'store_app_is_published']

    def get_current_version_number(self, obj):
        v = obj.current_version
        return v.version_number if v else 0

    def get_store_app_id(self, obj):
        from store.models import MiniApp
        app = MiniApp.objects.filter(genesis_project_id=obj.id).first()
        return app.id if app else None

    def get_store_app_is_published(self, obj):
        from store.models import MiniApp
        app = MiniApp.objects.filter(genesis_project_id=obj.id).first()
        return app.is_published if app else False

    def get_store_app_is_published(self, obj):
        from store.models import MiniApp
        app = MiniApp.objects.filter(genesis_project_id=obj.id).first()
        return app.is_published if app else False


class GenesisProjectDetailSerializer(serializers.ModelSerializer):
    current_version = ProjectVersionSerializer(read_only=True)
    versions = ProjectVersionListSerializer(many=True, read_only=True)
    conversation = ConversationTurnSerializer(many=True, read_only=True)
    store_app_id = serializers.SerializerMethodField()
    store_app_is_published = serializers.SerializerMethodField()

    class Meta:
        model = GenesisProject
        fields = ['id', 'title', 'is_deployed', 'deployed_version_number',
                  'created_at', 'updated_at',
                  'current_version', 'versions', 'conversation',
                  'store_app_id', 'store_app_is_published']

    def get_store_app_id(self, obj):
        from store.models import MiniApp
        app = MiniApp.objects.filter(genesis_project_id=obj.id).first()
        return app.id if app else None

    def get_store_app_is_published(self, obj):
        from store.models import MiniApp
        app = MiniApp.objects.filter(genesis_project_id=obj.id).first()
        return app.is_published if app else False


class GenesisQuotaSerializer(serializers.ModelSerializer):
    monthly_limit = serializers.IntegerField(read_only=True)
    remaining_creations = serializers.IntegerField(read_only=True)

    class Meta:
        model = GenesisQuota
        fields = [
            'plan', 'creations_this_month', 'monthly_limit',
            'extra_credits', 'remaining_creations', 'month_reset_date',
            'subscription_period', 'subscription_end_date',
        ]
