"""
GenesisAgent — LLM service that generates and iterates Mini-App HTML code.
Uses Anthropic Claude claude-sonnet-4-5 through the anthropic Python SDK.
"""
import re
import logging
from typing import Optional

from anthropic import Anthropic
from decouple import config

logger = logging.getLogger('genesis')

# ---------------------------------------------------------------------------
# System Prompt (CRITICAL — must not be altered)
# ---------------------------------------------------------------------------
GENESIS_SYSTEM_PROMPT = """Tu es GENESIS, l'Architecte IA d'ONDES CORE.
Ta tâche : Générer une App mobile ultra complète (HTML/JS/CSS) autonome en un seul fichier.

**RÈGLES TECHNIQUES STRICTES :**
1.  **Format :** Un seul fichier HTML. CSS dans `<style>`, JS dans `<script>`. N'hésite pas à utiiser des CDN externes pour simplifier la tâche.
2.  **Initialisation :** Attends l'événement `document.addEventListener('OndesReady', ...)` avant d'utiliser le SDK.
3.  **SDK ONDES v3.0 (OBLIGATOIRE) :** Utilise `window.Ondes`. Voici les modules disponibles :

    - **UI :** `Ondes.UI.showToast({message, type})`, `Ondes.UI.showModal({title, url/html})`, `Ondes.UI.showLoading()`, `Ondes.UI.hideLoading()`.
    - **Device :** `Ondes.Device.hapticFeedback('medium')`, `Ondes.Device.vibrate(500)`, `Ondes.Device.getGPSPosition()`, `Ondes.Device.scanQRCode()`.
    - **Storage :** `Ondes.Storage.set(key, val)`, `Ondes.Storage.get(key)`.
    - **Social (Complex) :** `Ondes.Social.getFeed()`, `Ondes.Social.publish({content})`, `Ondes.Social.follow(userId)`.
    - **Chat (E2EE) :** `Ondes.Chat.init()`, `Ondes.Chat.getConversations()`, `Ondes.Chat.send(convId, msg)`, `Ondes.Chat.onMessage(cb)`.
    - **Websocket :** `Ondes.Websocket.connect(url)`, `Ondes.Websocket.send(id, data)`, `Ondes.Websocket.onMessage(id, cb)`.
    - **UDP :** `Ondes.UDP.bind({port})`, `Ondes.UDP.send(id, msg, ip, port)`, `Ondes.UDP.onMessage(id, cb)`.

5.  **Gestion d'Erreur :** Entoure ton code JS principal d'un `try...catch` global qui affiche une `Ondes.UI.showToast` en cas d'erreur.

**SORTIE :** Renvoie UNIQUEMENT le code HTML brut. Pas de markdown."""

# ---------------------------------------------------------------------------
# Agent class
# ---------------------------------------------------------------------------

class GenesisAgent:
    """
    Wraps the Anthropic Claude API.

    Usage
    -----
    agent = GenesisAgent()
    html, description = agent.create("Une app météo avec animation de pluie")
    html2, description2 = agent.iterate(html, history, "Change le fond en violet")
    html3, description3 = agent.fix_error(html2, history, "TypeError: Cannot read property 'init' of undefined")
    """

    MODEL = "claude-sonnet-4-6"
    MAX_TOKENS = 64000

    def __init__(self):
        self._client = Anthropic(api_key=config('ANTHROPIC_API_KEY'))

    # ------------------------------------------------------------------
    # Public helpers
    # ------------------------------------------------------------------

    def create(self, user_prompt: str) -> tuple[str, str]:
        """
        Generate a brand-new Mini-App from a natural-language description.

        Returns
        -------
        (html_code, change_description)
        """
        messages = [{"role": "user", "content": user_prompt}]
        return self._call(messages)

    def iterate(
        self,
        current_html: str,
        history: list[dict],
        feedback: str,
    ) -> tuple[str, str]:
        """
        Modify existing code based on user feedback.

        Parameters
        ----------
        current_html : str
            The latest version of the generated HTML.
        history : list[dict]
            List of {"role": ..., "content": ...} dicts (excluding system).
        feedback : str
            The user's change request.

        Returns
        -------
        (html_code, change_description)
        """
        messages = list(history)
        messages.append({
            "role": "user",
            "content": (
                f"Voici le code actuel de la Mini-App :\n\n```html\n{current_html}\n```\n\n"
                f"Modification demandée : {feedback}"
            ),
        })
        return self._call(messages)

    def fix_error(
        self,
        current_html: str,
        history: list[dict],
        error_message: str,
        error_source: Optional[str] = None,
        error_line: Optional[int] = None,
    ) -> tuple[str, str]:
        """
        Auto-correct the code given a JS runtime error.

        Returns
        -------
        (html_code, change_description)
        """
        context = f"Erreur JS détectée dans la Mini-App : {error_message}"
        if error_source:
            context += f"\nSource : {error_source}"
        if error_line is not None:
            context += f"\nLigne : {error_line}"
        context += (
            f"\n\nVoici le code actuel :\n\n```html\n{current_html}\n```\n\n"
            "Corrige l'erreur et renvoie le fichier HTML complet et corrigé."
        )

        messages = list(history)
        messages.append({"role": "user", "content": context})
        return self._call(messages)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _call(self, messages: list[dict]) -> tuple[str, str]:
        """
        Send messages to Claude via streaming and return (html_code, change_description).
        Streaming is mandatory when max_tokens is large enough to exceed the 10-minute
        non-streaming timeout enforced by the Anthropic SDK.
        """
        with self._client.messages.stream(
            model=self.MODEL,
            max_tokens=self.MAX_TOKENS,
            system=GENESIS_SYSTEM_PROMPT,
            messages=messages,
        ) as stream:
            raw = stream.get_final_text().strip()

        html = self._extract_html(raw)
        description = self._extract_description(messages)
        logger.info("GenesisAgent: generated %d chars of HTML", len(html))
        return html, description

    @staticmethod
    def _extract_html(raw: str) -> str:
        """
        Strip any accidental markdown fences the LLM may have added.
        """
        # Remove ```html ... ``` fences
        match = re.search(r"```(?:html)?\s*([\s\S]+?)\s*```", raw, re.IGNORECASE)
        if match:
            return match.group(1).strip()
        return raw

    @staticmethod
    def _extract_description(messages: list[dict]) -> str:
        """
        Build a short change description from the last user message.
        """
        for msg in reversed(messages):
            if msg.get("role") == "user":
                content = msg["content"]
                # Keep first 120 chars as summary
                return content[:120].replace("\n", " ").strip()
        return "Generated by GENESIS"
