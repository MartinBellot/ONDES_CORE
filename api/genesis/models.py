from datetime import date
from django.db import models
from django.contrib.auth.models import User
import uuid


class GenesisProject(models.Model):
    """Top-level container for a user's generated Mini-App."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='genesis_projects')
    title = models.CharField(max_length=255, default='Untitled App')
    is_deployed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"[{self.user.username}] {self.title}"

    @property
    def current_version(self):
        """Returns the latest ProjectVersion, or None."""
        return self.versions.order_by('-version_number').first()


class ProjectVersion(models.Model):
    """Immutable snapshot of the generated HTML code at a given iteration."""
    project = models.ForeignKey(GenesisProject, on_delete=models.CASCADE, related_name='versions')
    version_number = models.PositiveIntegerField(default=1)
    html_code = models.TextField(blank=True)
    change_description = models.TextField(blank=True, help_text="Short changelog explaining what changed in this version")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-version_number']
        unique_together = [('project', 'version_number')]

    def __str__(self):
        return f"{self.project.title} v{self.version_number}"


class ConversationTurn(models.Model):
    """One message in the conversation between the user and GENESIS."""
    ROLES = [
        ('user', 'User'),
        ('assistant', 'Assistant'),
        ('system', 'System'),
    ]

    project = models.ForeignKey(GenesisProject, on_delete=models.CASCADE, related_name='conversation')
    role = models.CharField(max_length=16, choices=ROLES)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']

    def __str__(self):
        return f"[{self.role}] {self.project.title} — {self.timestamp:%Y-%m-%d %H:%M}"


class GenesisQuota(models.Model):
    """Tracks monthly creation quota, plan, and Stripe subscription for each user."""

    PLAN_FREE = 'free'
    PLAN_PRO = 'pro'
    PLAN_CHOICES = [('free', 'Free'), ('pro', 'Pro')]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='genesis_quota')
    plan = models.CharField(max_length=10, choices=PLAN_CHOICES, default=PLAN_FREE)

    # Monthly counter — reset automatically when month changes
    creations_this_month = models.PositiveIntegerField(default=0)
    month_reset_date = models.DateField(default=date.today)

    # Pay-as-you-go credits (each credit = 1 extra creation beyond quota)
    extra_credits = models.PositiveIntegerField(default=0)

    # Stripe
    stripe_customer_id = models.CharField(max_length=64, blank=True)
    stripe_subscription_id = models.CharField(max_length=64, blank=True)
    subscription_period = models.CharField(
        max_length=10,
        choices=[('monthly', 'Monthly'), ('yearly', 'Yearly'), ('', 'None')],
        blank=True,
        default='',
    )
    subscription_end_date = models.DateTimeField(null=True, blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Genesis Quota"

    @property
    def monthly_limit(self) -> int:
        return 50 if self.plan == self.PLAN_PRO else 5

    def _refresh_month(self):
        today = date.today()
        if today.year > self.month_reset_date.year or today.month > self.month_reset_date.month:
            self.creations_this_month = 0
            self.month_reset_date = today

    def can_create(self) -> bool:
        self._refresh_month()
        return self.creations_this_month < self.monthly_limit or self.extra_credits > 0

    def consume_creation(self):
        """Increments counter or deducts an extra credit. Saves immediately."""
        self._refresh_month()
        if self.creations_this_month < self.monthly_limit:
            self.creations_this_month += 1
        elif self.extra_credits > 0:
            self.extra_credits -= 1
            self.creations_this_month += 1
        else:
            raise ValueError("Quota épuisé")
        self.save()

    @property
    def remaining_creations(self) -> int:
        self._refresh_month()
        return max(0, self.monthly_limit - self.creations_this_month) + self.extra_credits

    def __str__(self):
        return f"{self.user.username} [{self.plan}] {self.creations_this_month}/{self.monthly_limit}"
