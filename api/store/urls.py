from django.urls import path
from .views import AppListView, RegisterView, CustomAuthToken, UserProfileView, MyAppsManagerView, AppVersionUploadView, MyAppsDetailView

urlpatterns = [
    path('apps/', AppListView.as_view(), name='app-list'),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', CustomAuthToken.as_view(), name='login'),
    path('auth/profile/', UserProfileView.as_view(), name='profile'),
    
    # Dev Studio
    path('studio/apps/', MyAppsManagerView.as_view(), name='studio-apps'),
    path('studio/apps/<int:pk>/', MyAppsDetailView.as_view(), name='studio-app-detail'),
    path('studio/apps/<int:app_id>/versions/', AppVersionUploadView.as_view(), name='studio-app-versions'),
]
