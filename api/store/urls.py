from django.urls import path
from .views import (
    # Auth
    AppListView, RegisterView, CustomAuthToken, UserProfileView, 
    # Store
    AppDetailView, FeaturedAppsView, TopAppsView, TrackDownloadView,
    CategoryListView, CategoryDetailView,
    # Reviews
    AppReviewsView, ReviewDetailView, ReviewDeveloperResponseView, ReviewHelpfulView,
    # Dev Studio
    MyAppsManagerView, AppVersionUploadView, MyAppsDetailView, AppScreenshotsView
)

urlpatterns = [
    # === Auth ===
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', CustomAuthToken.as_view(), name='login'),
    path('auth/profile/', UserProfileView.as_view(), name='profile'),
    
    # === Categories (avant apps pour éviter conflit) ===
    path('categories/', CategoryListView.as_view(), name='category-list'),
    path('categories/<slug:slug>/', CategoryDetailView.as_view(), name='category-detail'),
    
    # === Store Public (routes spécifiques AVANT les routes génériques) ===
    path('apps/featured/', FeaturedAppsView.as_view(), name='apps-featured'),
    path('apps/top/', TopAppsView.as_view(), name='apps-top'),
    path('apps/', AppListView.as_view(), name='app-list'),
    path('apps/<int:pk>/', AppDetailView.as_view(), name='app-detail'),
    path('apps/<int:app_id>/download/', TrackDownloadView.as_view(), name='app-download'),
    path('apps/<int:app_id>/reviews/', AppReviewsView.as_view(), name='app-reviews'),
    
    # === Reviews ===
    path('reviews/<uuid:review_id>/', ReviewDetailView.as_view(), name='review-detail'),
    path('reviews/<uuid:review_id>/respond/', ReviewDeveloperResponseView.as_view(), name='review-respond'),
    path('reviews/<uuid:review_id>/helpful/', ReviewHelpfulView.as_view(), name='review-helpful'),
    
    # === Dev Studio ===
    path('studio/apps/', MyAppsManagerView.as_view(), name='studio-apps'),
    path('studio/apps/<int:pk>/', MyAppsDetailView.as_view(), name='studio-app-detail'),
    path('studio/apps/<int:app_id>/versions/', AppVersionUploadView.as_view(), name='studio-app-versions'),
    path('studio/apps/<int:app_id>/screenshots/', AppScreenshotsView.as_view(), name='studio-app-screenshots'),
]
