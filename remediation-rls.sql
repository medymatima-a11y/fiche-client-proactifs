-- ══════════════════════════════════════════════════════════
-- REMÉDIATION RLS — CRM Proactifs Conseils Patrimoine
-- Date d'audit : 2026-05-26
--
-- À EXÉCUTER MANUELLEMENT dans Supabase > SQL Editor.
-- À LIRE ENTIÈREMENT avant exécution. Chaque bloc est commenté
-- avec son intention et son impact.
--
-- Pré-requis avant d'exécuter :
--   1. Avoir testé en mode dev / branche Supabase.
--   2. Avoir confirmé qu'aucune Edge Function ni script
--      externe n'utilise le rôle `anon` pour PATCH/DELETE
--      sur conformite, produits_client, ou les autres tables CRM.
--   3. Préparé une bascule pour la fiche-client.html (voir bloc D).
-- ══════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════
-- BLOC A — STOPPER L'HÉMORRAGIE : fermer les policies publiques
-- Impact : conformite et produits_client deviennent inaccessibles
-- aux non-authentifiés (anonymes + visiteurs).
-- Risque : si du code externe écrit dans ces tables, il cassera.
-- À vérifier : grep `conformite` et `produits_client` dans le code,
-- aucune écriture publique légitime trouvée à ce jour.
-- ══════════════════════════════════════════════════════════

drop policy if exists "conformite_all" on conformite;
drop policy if exists "produits_all"   on produits_client;

create policy "crm_conformite_all"      on conformite      for all to authenticated using (true) with check (true);
create policy "crm_produits_client_all" on produits_client for all to authenticated using (true) with check (true);


-- ══════════════════════════════════════════════════════════
-- BLOC B — DÉSACTIVER les anonymous sign-ins côté Supabase Auth
-- Action MANUELLE dans le dashboard, pas en SQL :
--   Project Settings > Authentication > Sign In / Up
--   > Désactiver « Allow anonymous sign-ins »
--
-- Impact : `db.auth.signInAnonymously()` retournera une erreur.
-- À adapter dans fiche-client.html (voir bloc D).
--
-- (Optionnel) Purger les 29 users anonymes existants :
-- ⚠ Ne supprime PAS les lignes clients ni documents qu'ils ont créés —
-- ces lignes ont été insérées via INSERT, leur ownership n'est pas dans auth.users.
-- ══════════════════════════════════════════════════════════

-- À DÉCOMMENTER UNIQUEMENT après désactivation des anonymous sign-ins :
-- delete from auth.users where is_anonymous = true;


-- ══════════════════════════════════════════════════════════
-- BLOC C — SETTINGS : sortir la clé Brevo de la base
-- La clé brevo_api_key est lisible par tout authenticated (incl. anonymes).
-- Solution : déplacer la clé dans les Vault de Supabase (extension `vault`),
-- ou la stocker en variable d'environnement Edge Function.
-- Les fonctions notify_make_new_client et send_reminders lisent settings —
-- elles devront être ré-écrites en SECURITY DEFINER avec accès direct au Vault.
--
-- Étapes (à faire dans cet ordre, manuellement) :
--   1. Activer l'extension `vault` (Database > Extensions).
--   2. Stocker la clé : select vault.create_secret('<brevo_key>', 'brevo_api_key');
--   3. Modifier les fonctions ci-dessous pour lire depuis vault.decrypted_secrets.
--   4. delete from settings where key = 'brevo_api_key';
--
-- En attendant (mesure transitoire), au moins restreindre la lecture
-- aux seuls users authentifiés NON-anonymes :
-- ══════════════════════════════════════════════════════════

drop policy if exists "CRM acces settings" on settings;

create policy "settings_read_real_users"  on settings for select to authenticated
  using ((auth.jwt() ->> 'is_anonymous')::boolean is not true);

create policy "settings_write_real_users" on settings for all to authenticated
  using ((auth.jwt() ->> 'is_anonymous')::boolean is not true)
  with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);


-- ══════════════════════════════════════════════════════════
-- BLOC D — Bloquer les anonymes sur les tables CRM
-- Idem : restreindre `to authenticated` aux users qui ne sont PAS anonymes.
-- Les policies INSERT publiques sur clients/documents restent ouvertes
-- (le formulaire fiche-client.html en dépend).
--
-- ⚠ Avant d'exécuter ce bloc :
--   - tester que l'authentification Medy fonctionne toujours,
--   - vérifier que jwt.is_anonymous est bien renseigné (logguer auth.jwt()
--     depuis l'interface CRM en mode dev).
-- ══════════════════════════════════════════════════════════

-- Helper : prédicat « user authentifié et non anonyme »
-- (PostgreSQL ne supporte pas les fonctions inline dans CREATE POLICY,
-- mais on peut le répliquer)

do $$
declare
  tbl text;
  policy_name text;
begin
  for tbl, policy_name in
    select unnest(array['clients','documents','rdv','interactions','echeances','projets','bilans','missions','client_emails']),
           unnest(array['crm_clients_all','crm_documents_all','crm_rdv_all','crm_interactions_all','crm_echeances_all','crm_projets_all','crm_bilans_all','crm_missions_all','crm_emails_all'])
  loop
    execute format('drop policy if exists %I on %I', policy_name, tbl);
    execute format(
      'create policy %I on %I for all to authenticated using ((auth.jwt() ->> ''is_anonymous'')::boolean is not true) with check ((auth.jwt() ->> ''is_anonymous'')::boolean is not true)',
      policy_name, tbl
    );
  end loop;
end $$;

-- Idem sur conformite et produits_client (déjà recréés en bloc A)
drop policy if exists "crm_conformite_all"      on conformite;
drop policy if exists "crm_produits_client_all" on produits_client;
create policy "crm_conformite_all" on conformite for all to authenticated
  using ((auth.jwt() ->> 'is_anonymous')::boolean is not true)
  with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_produits_client_all" on produits_client for all to authenticated
  using ((auth.jwt() ->> 'is_anonymous')::boolean is not true)
  with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);


-- ══════════════════════════════════════════════════════════
-- BLOC E — Activer la RLS sur les tables SEO
-- Ces tables n'ont pas de policies. Décide d'abord du modèle :
--   Option 1 : 100% backend, pas d'accès via clé anon → bloquer total
--   Option 2 : lecture publique pour afficher les articles sur le site
-- ══════════════════════════════════════════════════════════

alter table seo_topics   enable row level security;
alter table seo_articles enable row level security;
alter table seo_audits   enable row level security;

-- Option 1 (recommandé si l'agent SEO utilise la service_role key) — pas de policy = pas d'accès anon
-- → ne rien créer.

-- Option 2 (si tu veux exposer les articles publiés sur le site) — décommenter :
-- create policy "seo_articles_public_read" on seo_articles
--   for select to anon
--   using (statut = 'publie');


-- ══════════════════════════════════════════════════════════
-- BLOC F — Adaptations frontend requises
-- (rappel — pas du SQL, à faire dans fiche-client.html / crm-interface.html)
--
-- 1. fiche-client.html ligne ~956 et ~1681 :
--    Remplacer `db.auth.signInAnonymously()` par un POST direct avec
--    uniquement la clé `apikey` (la policy `insert_open` est `to public`,
--    pas besoin d'un JWT authenticated).
--
-- 2. Mode édition (fiche-client.html?clientId=…) :
--    Ne plus fonctionner sans authentification réelle. Solutions :
--      a) Désactiver le mode édition publique, n'éditer que depuis le CRM.
--      b) Générer un lien magique signé côté serveur (Edge Function)
--         qui crée une session limitée à un seul UUID client.
--
-- 3. crm-interface.html — login normal (déjà conforme).
-- ══════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════
-- BLOC G — Tests de validation (à exécuter après remédiation)
-- ══════════════════════════════════════════════════════════

-- Vérifier qu'aucune policy publique ne reste sur les tables sensibles :
-- select tablename, policyname, roles, cmd
-- from pg_policies
-- where schemaname = 'public'
--   and 'public' = any(roles)
--   and cmd != 'INSERT';
-- → résultat attendu : 0 lignes

-- Vérifier RLS activée partout :
-- select relname, relrowsecurity
-- from pg_class
-- where relnamespace = 'public'::regnamespace and relkind = 'r'
-- order by relname;
-- → toutes les tables doivent être à `t`.
