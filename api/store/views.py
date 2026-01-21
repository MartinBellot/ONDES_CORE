from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.permissions import IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework import parsers
from django.db.models import Q, Avg, Count
from django.utils import timezone
from .models import MiniApp, UserProfile, AppVersion, Category, AppScreenshot, AppReview
from .serializers import (
    MiniAppSerializer, MiniAppListSerializer, MiniAppDetailSerializer,
    RegisterSerializer, UserProfileSerializer, AppVersionSerializer,
    CategorySerializer, AppScreenshotSerializer, 
    AppReviewSerializer, AppReviewCreateSerializer, DeveloperResponseSerializer
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


# ============== CATEGORIES API ==============

class CategoryListView(APIView):
    """Liste toutes les catégories"""
    
    def get(self, request):
        categories = Category.objects.annotate(apps_count=Count('apps'))
        serializer = CategorySerializer(categories, many=True, context={'request': request})
        return Response(serializer.data)


class CategoryDetailView(APIView):
    """Apps d'une catégorie spécifique"""
    
    def get(self, request, slug):
        try:
            category = Category.objects.get(slug=slug)
        except Category.DoesNotExist:
            return Response({'error': 'Category not found'}, status=status.HTTP_404_NOT_FOUND)
        
        apps = MiniApp.objects.filter(category=category)
        
        # Pagination
        limit = int(request.query_params.get('limit', 20))
        offset = int(request.query_params.get('offset', 0))
        
        total = apps.count()
        apps = apps[offset:offset + limit]
        
        serializer = MiniAppListSerializer(apps, many=True, context={'request': request})
        
        return Response({
            'category': CategorySerializer(category).data,
            'apps': serializer.data,
            'total': total,
            'limit': limit,
            'offset': offset
        })


# ============== APPS API ==============

class AppListView(APIView):
    """Liste des apps avec recherche et filtres"""
    
    def get(self, request):
        apps = MiniApp.objects.all()
        
        # Recherche textuelle
        search = request.query_params.get('search', '').strip()
        if search:
            apps = apps.filter(
                Q(name__icontains=search) |
                Q(description__icontains=search) |
                Q(tags__icontains=search) |
                Q(bundle_id__icontains=search)
            )
        
        # Filtre par catégorie
        category = request.query_params.get('category', '')
        if category:
            apps = apps.filter(category__slug=category)
        
        # Filtre par âge
        age_rating = request.query_params.get('age_rating', '')
        if age_rating:
            apps = apps.filter(age_rating=age_rating)
        
        # Tri
        sort = request.query_params.get('sort', 'featured')
        if sort == 'newest':
            apps = apps.order_by('-created_at')
        elif sort == 'popular':
            apps = apps.order_by('-downloads_count')
        elif sort == 'rating':
            apps = apps.annotate(avg_rating=Avg('reviews__rating')).order_by('-avg_rating')
        elif sort == 'name':
            apps = apps.order_by('name')
        else:  # featured (default)
            apps = apps.order_by('-featured', '-downloads_count', '-created_at')
        
        # Pagination
        limit = int(request.query_params.get('limit', 50))
        offset = int(request.query_params.get('offset', 0))
        
        total = apps.count()
        apps = apps[offset:offset + limit]
        
        serializer = MiniAppListSerializer(apps, many=True, context={'request': request})
        
        return Response({
            'apps': serializer.data,
            'total': total,
            'limit': limit,
            'offset': offset
        })


class AppDetailView(APIView):
    """Détails complets d'une app (pour page détail Store)"""
    
    def get(self, request, pk):
        try:
            app = MiniApp.objects.get(pk=pk)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        serializer = MiniAppDetailSerializer(app, context={'request': request})
        return Response(serializer.data)


class FeaturedAppsView(APIView):
    """Apps mises en avant"""
    
    def get(self, request):
        featured = MiniApp.objects.filter(featured=True).order_by('featured_order')[:10]
        serializer = MiniAppListSerializer(featured, many=True, context={'request': request})
        return Response(serializer.data)


class TopAppsView(APIView):
    """Top apps par catégorie ou général"""
    
    def get(self, request):
        category = request.query_params.get('category', '')
        list_type = request.query_params.get('type', 'downloads')  # downloads, rating, new
        limit = int(request.query_params.get('limit', 20))
        
        apps = MiniApp.objects.all()
        
        if category:
            apps = apps.filter(category__slug=category)
        
        if list_type == 'rating':
            apps = apps.annotate(avg_rating=Avg('reviews__rating')).order_by('-avg_rating')
        elif list_type == 'new':
            apps = apps.order_by('-created_at')
        else:  # downloads
            apps = apps.order_by('-downloads_count')
        
        apps = apps[:limit]
        serializer = MiniAppListSerializer(apps, many=True, context={'request': request})
        return Response(serializer.data)


# ============== REVIEWS API ==============

class AppReviewsView(APIView):
    """Avis d'une app"""
    permission_classes = [IsAuthenticatedOrReadOnly]
    
    def get(self, request, app_id):
        """Liste des avis"""
        try:
            app = MiniApp.objects.get(pk=app_id)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Tri
        sort = request.query_params.get('sort', 'recent')  # recent, helpful, rating_high, rating_low
        reviews = app.reviews.all()
        
        if sort == 'helpful':
            reviews = reviews.order_by('-helpful_count', '-created_at')
        elif sort == 'rating_high':
            reviews = reviews.order_by('-rating', '-created_at')
        elif sort == 'rating_low':
            reviews = reviews.order_by('rating', '-created_at')
        else:  # recent
            reviews = reviews.order_by('-created_at')
        
        # Pagination
        limit = int(request.query_params.get('limit', 20))
        offset = int(request.query_params.get('offset', 0))
        
        total = reviews.count()
        reviews = reviews[offset:offset + limit]
        
        serializer = AppReviewSerializer(reviews, many=True, context={'request': request})
        
        return Response({
            'reviews': serializer.data,
            'total': total,
            'average_rating': app.average_rating,
            'ratings_count': app.ratings_count,
            'limit': limit,
            'offset': offset
        })
    
    def post(self, request, app_id):
        """Créer ou mettre à jour un avis"""
        try:
            app = MiniApp.objects.get(pk=app_id)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Vérifier si l'utilisateur a déjà un avis
        existing_review = AppReview.objects.filter(app=app, user=request.user).first()
        
        serializer = AppReviewCreateSerializer(data=request.data)
        if serializer.is_valid():
            if existing_review:
                # Mise à jour
                existing_review.rating = serializer.validated_data['rating']
                existing_review.title = serializer.validated_data.get('title', '')
                existing_review.content = serializer.validated_data.get('content', '')
                existing_review.app_version = serializer.validated_data.get('app_version', '')
                existing_review.save()
                review = existing_review
            else:
                # Création
                review = AppReview.objects.create(
                    app=app,
                    user=request.user,
                    **serializer.validated_data
                )
            
            return Response(
                AppReviewSerializer(review, context={'request': request}).data,
                status=status.HTTP_201_CREATED if not existing_review else status.HTTP_200_OK
            )
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ReviewDetailView(APIView):
    """Détail d'un avis (suppression, réponse développeur)"""
    permission_classes = [IsAuthenticated]
    
    def delete(self, request, review_id):
        """Supprimer son avis"""
        try:
            review = AppReview.objects.get(id=review_id, user=request.user)
        except AppReview.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)
        
        review.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReviewDeveloperResponseView(APIView):
    """Réponse du développeur à un avis"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, review_id):
        try:
            review = AppReview.objects.get(id=review_id)
        except AppReview.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Vérifier que l'utilisateur est l'auteur de l'app
        if review.app.author != request.user:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        serializer = DeveloperResponseSerializer(data=request.data)
        if serializer.is_valid():
            review.developer_response = serializer.validated_data['response']
            review.developer_response_date = timezone.now()
            review.save()
            return Response(AppReviewSerializer(review, context={'request': request}).data)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ReviewHelpfulView(APIView):
    """Marquer un avis comme utile"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, review_id):
        try:
            review = AppReview.objects.get(id=review_id)
        except AppReview.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)
        
        review.helpful_count += 1
        review.save()
        return Response({'helpful_count': review.helpful_count})


# ============== DEV STUDIO API ==============

class MyAppsManagerView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser]

    def get(self, request):
        apps = MiniApp.objects.filter(author=request.user)
        serializer = MiniAppSerializer(apps, many=True, context={'request': request})
        return Response(serializer.data)
    
    def post(self, request):
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
        
        zip_file = request.FILES.get('zip_file')
        version_number = request.data.get('version_number')
        release_notes = request.data.get('release_notes', '')

        if not zip_file or not version_number:
             return Response({'error': 'zip_file and version_number required'}, status=status.HTTP_400_BAD_REQUEST)

        # Calculer la taille
        app.size_bytes = zip_file.size
        app.whats_new = release_notes
        app.save()

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


class AppScreenshotsView(APIView):
    """Gestion des screenshots d'une app (Dev Studio)"""
    permission_classes = [IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser]
    
    def get(self, request, app_id):
        try:
            app = MiniApp.objects.get(id=app_id, author=request.user)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        screenshots = app.screenshots.all()
        serializer = AppScreenshotSerializer(screenshots, many=True, context={'request': request})
        return Response(serializer.data)
    
    def post(self, request, app_id):
        try:
            app = MiniApp.objects.get(id=app_id, author=request.user)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        image = request.FILES.get('image')
        if not image:
            return Response({'error': 'image required'}, status=status.HTTP_400_BAD_REQUEST)
        
        device_type = request.data.get('device_type', 'phone')
        caption = request.data.get('caption', '')
        order = int(request.data.get('order', app.screenshots.count()))
        
        screenshot = AppScreenshot.objects.create(
            app=app,
            image=image,
            device_type=device_type,
            caption=caption,
            order=order
        )
        
        return Response(AppScreenshotSerializer(screenshot, context={'request': request}).data, status=status.HTTP_201_CREATED)
    
    def delete(self, request, app_id):
        """Supprimer un screenshot par ID (passé en query param)"""
        try:
            app = MiniApp.objects.get(id=app_id, author=request.user)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        screenshot_id = request.query_params.get('screenshot_id')
        if not screenshot_id:
            return Response({'error': 'screenshot_id required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            screenshot = AppScreenshot.objects.get(id=screenshot_id, app=app)
            screenshot.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except AppScreenshot.DoesNotExist:
            return Response({'error': 'Screenshot not found'}, status=status.HTTP_404_NOT_FOUND)


class ScreenshotDetailView(APIView):
    """Gestion d'un screenshot individuel (Dev Studio)"""
    permission_classes = [IsAuthenticated]
    
    def delete(self, request, app_id, screenshot_id):
        """Supprimer un screenshot"""
        try:
            app = MiniApp.objects.get(id=app_id, author=request.user)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        try:
            screenshot = AppScreenshot.objects.get(id=screenshot_id, app=app)
            screenshot.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except AppScreenshot.DoesNotExist:
            return Response({'error': 'Screenshot not found'}, status=status.HTTP_404_NOT_FOUND)
    
    def patch(self, request, app_id, screenshot_id):
        """Modifier un screenshot (caption, order)"""
        try:
            app = MiniApp.objects.get(id=app_id, author=request.user)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        try:
            screenshot = AppScreenshot.objects.get(id=screenshot_id, app=app)
        except AppScreenshot.DoesNotExist:
            return Response({'error': 'Screenshot not found'}, status=status.HTTP_404_NOT_FOUND)
        
        if 'caption' in request.data:
            screenshot.caption = request.data['caption']
        if 'order' in request.data:
            screenshot.order = int(request.data['order'])
        if 'device_type' in request.data:
            screenshot.device_type = request.data['device_type']
        
        screenshot.save()
        return Response(AppScreenshotSerializer(screenshot, context={'request': request}).data)


class ScreenshotReorderView(APIView):
    """Réorganiser les screenshots (Dev Studio)"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, app_id):
        """Réorganiser les screenshots avec une liste d'IDs ordonnés"""
        try:
            app = MiniApp.objects.get(id=app_id, author=request.user)
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)
        
        ordered_ids = request.data.get('ordered_ids', [])
        if not ordered_ids:
            return Response({'error': 'ordered_ids required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Mettre à jour l'ordre de chaque screenshot
        for index, screenshot_id in enumerate(ordered_ids):
            try:
                screenshot = AppScreenshot.objects.get(id=screenshot_id, app=app)
                screenshot.order = index
                screenshot.save()
            except AppScreenshot.DoesNotExist:
                continue
        
        # Retourner les screenshots mis à jour
        screenshots = app.screenshots.all().order_by('order')
        return Response(AppScreenshotSerializer(screenshots, many=True, context={'request': request}).data)


class TrackDownloadView(APIView):
    """Incrémenter le compteur de téléchargements"""
    
    def post(self, request, app_id):
        try:
            app = MiniApp.objects.get(id=app_id)
            app.downloads_count += 1
            app.save()
            return Response({'downloads_count': app.downloads_count})
        except MiniApp.DoesNotExist:
            return Response({'error': 'App not found'}, status=status.HTTP_404_NOT_FOUND)


class DeveloperStatsView(APIView):
    """Statistiques du développeur pour la page profil"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Récupérer toutes les apps de l'utilisateur
        my_apps = MiniApp.objects.filter(author=user)
        
        # Statistiques globales
        total_apps = my_apps.count()
        total_downloads = sum(app.downloads_count for app in my_apps)
        
        # Note moyenne globale
        from django.db.models import Avg
        avg_rating_result = AppReview.objects.filter(app__author=user).aggregate(avg=Avg('rating'))
        average_rating = round(avg_rating_result['avg'] or 0, 1)
        
        # Nombre total d'avis reçus
        total_reviews = AppReview.objects.filter(app__author=user).count()
        
        # Apps sérialisées (les 6 dernières)
        recent_apps = my_apps.order_by('-updated_at')[:6]
        apps_data = MiniAppListSerializer(recent_apps, many=True, context={'request': request}).data
        
        # Top app (la plus téléchargée)
        top_app = my_apps.order_by('-downloads_count').first()
        top_app_data = MiniAppListSerializer(top_app, context={'request': request}).data if top_app else None
        
        # Statistiques par mois (downloads des 6 derniers mois) - simplifié
        from django.utils import timezone
        from datetime import timedelta
        
        # Catégories utilisées
        categories_used = list(my_apps.exclude(category__isnull=True).values_list('category__name', flat=True).distinct())
        
        return Response({
            'stats': {
                'total_apps': total_apps,
                'total_downloads': total_downloads,
                'average_rating': average_rating,
                'total_reviews': total_reviews,
            },
            'recent_apps': apps_data,
            'top_app': top_app_data,
            'categories_used': categories_used,
            'member_since': user.date_joined.isoformat(),
        })
