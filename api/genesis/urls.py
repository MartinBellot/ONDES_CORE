from django.urls import path
from .views import (
    GenesisProjectListView,
    GenesisCreateView,
    GenesisIterateView,
    GenesisReportErrorView,
    GenesisDeployView,
    GenesisProjectDetailView,
    GenesisVersionDetailView,
    GenesisSaveEditView,
)

urlpatterns = [
    # List all projects
    path('', GenesisProjectListView.as_view(), name='genesis-list'),
    # Create new project from prompt
    path('create/', GenesisCreateView.as_view(), name='genesis-create'),
    # Project-level operations
    path('<uuid:project_id>/', GenesisProjectDetailView.as_view(), name='genesis-detail'),
    path('<uuid:project_id>/iterate/', GenesisIterateView.as_view(), name='genesis-iterate'),
    path('<uuid:project_id>/report_error/', GenesisReportErrorView.as_view(), name='genesis-report-error'),
    path('<uuid:project_id>/deploy/', GenesisDeployView.as_view(), name='genesis-deploy'),
    # Version history
    path('<uuid:project_id>/versions/<int:version_id>/', GenesisVersionDetailView.as_view(), name='genesis-version-detail'),
    # Manual HTML edit
    path('<uuid:project_id>/save_edit/', GenesisSaveEditView.as_view(), name='genesis-save-edit'),
]
