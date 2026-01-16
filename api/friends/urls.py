from django.urls import path
from .views import (
    FriendsListView, FriendRequestView, PendingRequestsView, SentRequestsView,
    AcceptFriendRequestView, RejectFriendRequestView, BlockUserView, 
    UnblockUserView, RemoveFriendView, SearchUsersView, BlockedUsersView
)

app_name = 'friends'

urlpatterns = [
    path('', FriendsListView.as_view(), name='list'),
    path('request/', FriendRequestView.as_view(), name='request'),
    path('pending/', PendingRequestsView.as_view(), name='pending'),
    path('sent/', SentRequestsView.as_view(), name='sent'),
    path('<int:friendship_id>/accept/', AcceptFriendRequestView.as_view(), name='accept'),
    path('<int:friendship_id>/reject/', RejectFriendRequestView.as_view(), name='reject'),
    path('<int:friendship_id>/remove/', RemoveFriendView.as_view(), name='remove'),
    path('block/', BlockUserView.as_view(), name='block'),
    path('unblock/', UnblockUserView.as_view(), name='unblock'),
    path('blocked/', BlockedUsersView.as_view(), name='blocked'),
    path('search/', SearchUsersView.as_view(), name='search'),
]
