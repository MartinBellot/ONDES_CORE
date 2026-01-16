from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.permissions import IsAuthenticated
from rest_framework import parsers
from .models import MiniApp, UserProfile, AppVersion
from .serializers import (
    MiniAppSerializer, RegisterSerializer, UserProfileSerializer, 
    AppVersionSerializer
)


# ============== AUTH API ==============

class RegisterView(APIView):
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            token, created = Token.objects.get_or_create(user=user)
            return Response({'token': token.key}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CustomAuthToken(ObtainAuthToken):
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        token, created = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'user_id': user.pk,
            'email': user.email
        })


class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            profile = UserProfile.objects.create(user=request.user)
            
        serializer = UserProfileSerializer(profile, context={'request': request})
        # Add ID for easier debugging
        data = serializer.data
        data['id'] = request.user.id
        return Response(data)
    
    def put(self, request):
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            profile = UserProfile.objects.create(user=request.user)

        serializer = UserProfileSerializer(profile, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ============== APPS API ==============

class AppListView(APIView):
    def get(self, request):
        apps = MiniApp.objects.all()
        # Pass request context for absolute URLs (icons/files)
        serializer = MiniAppSerializer(apps, many=True, context={'request': request})
        return Response(serializer.data)


class MyAppsManagerView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser]

    def get(self, request):
        # List apps authored by current user
        apps = MiniApp.objects.filter(author=request.user)
        serializer = MiniAppSerializer(apps, many=True, context={'request': request})
        return Response(serializer.data)
    
    def post(self, request):
        # Create a new app
        serializer = MiniAppSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save(author=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MyAppsDetailView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser]

    def get_object(self, pk, user):
        try:
            return MiniApp.objects.get(pk=pk, author=user)
        except MiniApp.DoesNotExist:
            return None

    def get(self, request, pk):
        app = self.get_object(pk, request.user)
        if not app:
            return Response(status=status.HTTP_404_NOT_FOUND)
        serializer = MiniAppSerializer(app, context={'request': request})
        return Response(serializer.data)

    def put(self, request, pk):
        app = self.get_object(pk, request.user)
        if not app:
            return Response(status=status.HTTP_404_NOT_FOUND)
        serializer = MiniAppSerializer(app, data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def patch(self, request, pk):
        app = self.get_object(pk, request.user)
        if not app:
            return Response(status=status.HTTP_404_NOT_FOUND)
        serializer = MiniAppSerializer(app, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        app = self.get_object(pk, request.user)
        if not app:
            return Response(status=status.HTTP_404_NOT_FOUND)
        app.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AppVersionUploadView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser]

    def post(self, request, app_id):
        try:
            app = MiniApp.objects.get(id=app_id, author=request.user)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found or not owned by you'}, status=status.HTTP_404_NOT_FOUND)
        
        # Manually handling upload because of nested relationship logic
        zip_file = request.FILES.get('zip_file')
        version_number = request.data.get('version_number')
        release_notes = request.data.get('release_notes', '')

        if not zip_file or not version_number:
             return Response({'error': 'zip_file and version_number required'}, status=status.HTTP_400_BAD_REQUEST)

        # Deactivate old versions
        AppVersion.objects.filter(app=app).update(is_active=False)

        version = AppVersion.objects.create(
            app=app,
            version_number=version_number,
            zip_file=zip_file,
            release_notes=release_notes,
            is_active=True
        )
        
        return Response(AppVersionSerializer(version).data, status=status.HTTP_201_CREATED)


