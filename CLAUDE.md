# Contexte — CRM Proactifs Conseils

## Localisation
`C:\Users\medym\Dropbox\10-Claude projets\Proactifs conseils\Création appli Proacitfs\CRM proactifs`

Ce dossier fait partie du regroupement **« Création appli Proacitfs »**, qui
contient les briques techniques de l'écosystème Proactifs :

- `App email marketing\` — campagnes Brevo, séquences, newsletters
- `CRM proactifs\` — *ce dossier* — CRM custom Supabase + Vercel
- (à venir) autres applis métier (génération bilans PDF, dashboards, etc.)

Voir le `CLAUDE.md` à la racine de `Création appli Proacitfs\` pour la vue
d'ensemble et `Création appli Proacitfs\REGISTRE-COWORK.md` pour la
cartographie complète des outils.

## Qui je suis
Medy Matima — Proactifs Conseils (cabinet de gestion de patrimoine, Colombes 92).
Ce dossier contient mon **CRM custom**, source unique de vérité pour tous mes
contacts (clients, prospects) et toute mon activité commerciale.

## Architecture technique

| Couche | Technologie | Rôle |
|---|---|---|
| Base de données | Supabase (PostgreSQL) | Stockage clients, RDV, documents, bilans |
| Sécurité | Row Level Security (RLS) | Policies anon (formulaire) + authenticated (CRM) |
| Stockage fichiers | Supabase Storage (bucket `documents`) | Pièces justificatives clients |
| Frontend | HTML statique | `crm-interface.html`, `fiche-client.html` |
| Déploiement | Vercel | Dossiers `deploy/` et `deploy-crm/` |
| Versionning | Git via MCP GitHub (ou push-to-github.bat pour gros fichiers) | Suivi des modifs |

## Modèle de données (résumé)

Voir `supabase-schema.sql` pour le détail. 4 tables principales :

- **`clients`** : couple (c1, c2), adresse, situation familiale, revenus,
  banques, épargne/immobilier/crédits en JSONB. Statut CRM
  (`prospect`/`actif`/`inactif`/`archive`).
- **`documents`** : pièces uploadées par le client ou ajoutées en RDV.
- **`rdv`** : rendez-vous avec compte-rendu, prochaine action, date de relance.
- **`bilans`** : bilans patrimoniaux avec profil risque, horizon, objectif,
  analyse et préconisations (JSONB).

## Place dans l'architecture globale

Ce CRM est la **source unique de vérité** pour tous mes outils :

**Sources qui alimentent le CRM :**
- Site web (`proactifs-conseils.fr`) → formulaire fiche client → INSERT anon
- Saisie manuelle pendant les RDV (interface CRM)
- Import Excel (migration initiale)
- Contacts Brevo legacy (à dédoublonner et importer)

**Consommateurs qui exploitent le CRM :**
- Devis/factures (skill `proactifs-billing`)
- Suivi RDV et relances
- Segmentation pour campagnes Brevo (via Make.com)
- Bilans patrimoniaux

## Outils à privilégier dans ce dossier

### Connecteurs MCP
- **GitHub** (`mcp__ef8e1bd4…__push_files`) — **à utiliser en priorité pour pousser les fichiers**
  vers le repo `medymatima-a11y/fiche-client-proactifs` branche `master`.
  Remplace le `push-to-github.bat` pour les fichiers ≤ ~25 Ko. Pour les fichiers
  plus lourds (ex. `crm-interface.html` ≈ 242 Ko), le bat reste nécessaire car
  le contenu dépasse la fenêtre de contexte de Claude.
  Ne jamais passer par computer use / explorateur de fichiers pour pusher.
- **Supabase** — pour lire/écrire dans la base, ajuster le schéma, gérer les
  policies RLS, déboguer des requêtes.
- **Make.com** — pour les scénarios de synchronisation
  (CRM ↔ Brevo, CRM → notifications email, etc.).

### Skills à utiliser
- `engineering:debug` — debug des erreurs Supabase ou frontend.
- `engineering:code-review` — avant de pousser sur GitHub.
- `engineering:system-design` — pour les évolutions d'architecture.
- `redaction-naturelle-fr` — pour les emails automatisés que le CRM enverra.
- `docx` / `pdf` — pour générer les bilans patrimoniaux en sortie.

### Outils à NE PAS utiliser ici
- `proactifs-design` — c'est pour le site public, pas pour le CRM interne
  (même si l'interface peut s'en inspirer pour la cohérence visuelle).
- `proactifs-billing` — c'est un skill séparé pour Henrri, à appeler depuis
  ailleurs avec les données extraites du CRM.

## Workflow type d'évolution

1. Identifier le besoin (nouvelle table, nouveau champ, nouvelle vue HTML)
2. Modifier `supabase-schema.sql` si évolution de base
3. Appliquer la migration via MCP Supabase ou SQL Editor Supabase
4. Adapter le frontend (`crm-interface.html`, `fiche-client.html`)
5. Tester en local
6. Push via MCP GitHub (`push_files`) si fichier ≤ 25 Ko, sinon `push-to-github.bat`

## Fichiers clés
- `supabase-schema.sql` — schéma de référence
- `crm-interface.html` — interface principale (vue Medy authentifié)
- `fiche-client.html` — formulaire public client
- `architecture_crm_proactifs.html` — doc d'architecture HTML
- `Info.txt` — identifiants (NE JAMAIS exposer en clair dans un output)
- `deploy-vercel.bat` / `push-to-github.bat` — scripts de déploiement

## TODOs courants à proposer
- Dédoublonnage contacts Brevo legacy → CRM
- Synchro bidirectionnelle CRM ↔ Brevo via Make.com
- Connexion du formulaire site web (`proactifs-conseils.fr`) à l'endpoint
  Supabase pour création automatique de fiches prospect
- Génération automatique du bilan patrimonial en PDF depuis les données CRM
