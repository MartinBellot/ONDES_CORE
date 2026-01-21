from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register('conversations', views.ConversationViewSet, basename='conversation')

urlpatterns = [
    # Gestion des clés E2EE
    path('keys/', views.KeyPairView.as_view(), name='chat-keypair'),
    path('keys/public/', views.PublicKeysView.as_view(), name='chat-public-keys'),
    
    # Conversation privée rapide
    path('dm/', views.StartPrivateConversationView.as_view(), name='chat-dm'),
    
    # ViewSet conversations
    path('', include(router.urls)),
]
