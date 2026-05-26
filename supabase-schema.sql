-- ══════════════════════════════════════════════════════════
-- CRM Proactifs Conseils Patrimoine — Schéma Supabase
-- Source de vérité : dump du projet `ullnkylrixdvormohryl`
-- Régénéré le 2026-05-26 depuis l'état réel de la base.
-- À jour : 14 tables, triggers, fonctions, policies RLS.
--
-- SÉCURITÉ : remédiation RLS appliquée le 2026-05-26.
-- Toutes les policies CRM sont gatées sur is_anonymous is not true.
-- RLS activée sur les 15 tables (y compris SEO).
-- Voir `remediation-rls.sql` pour l'historique des corrections.
-- ══════════════════════════════════════════════════════════

-- ── EXTENSIONS ─────────────────────────────────────────────
-- pg_net est utilisé par notify_make_new_client / send_reminders
create extension if not exists pg_net with schema extensions;
-- vault stocke la clé API Brevo (chiffrée, accessible uniquement par les fonctions SECURITY DEFINER)
create extension if not exists supabase_vault;


-- ══════════════════════════════════════════════════════════
-- TABLES CRM
-- ══════════════════════════════════════════════════════════

-- ── CLIENTS ────────────────────────────────────────────────
create table clients (
  id                    uuid primary key default gen_random_uuid(),
  created_at            timestamptz default now(),
  updated_at            timestamptz default now(),

  -- Statut CRM
  statut                text default 'prospect'
                        check (statut in ('prospect','client','actif','inactif','archive')),
  date_entree           date default current_date,
  notes                 text,
  source                text default 'crm',
  type_dossier          text check (type_dossier in ('patrimonial','courtage','mixte')),
  situation             text,

  -- Conjoint 1
  nom_c1                text,
  prenom_c1             text,
  date_naissance_c1     date,
  lieu_naissance_c1     text,
  telephone_c1          text,
  email_c1              text,
  profession_c1         text,
  statut_pro_c1         text,
  entreprise_c1         text,

  -- Conjoint 2
  nom_c2                text,
  prenom_c2             text,
  date_naissance_c2     date,
  lieu_naissance_c2     text,
  telephone_c2          text,
  email_c2              text,
  profession_c2         text,
  statut_pro_c2         text,
  entreprise_c2         text,

  -- Adresse principale
  adresse               text,
  code_postal           text,
  ville                 text,

  -- Adresse conjoint si différente
  c2_adresse            text,
  c2_code_postal        text,
  c2_ville              text,

  -- Situation familiale
  statut_marital        text,
  regime                text,
  date_union            date,
  enfants_noms          text,
  enfants_dob           text,

  -- Revenus & fiscalité
  salaire_c1            numeric,
  salaire_c2            numeric,
  impot_c1              numeric,
  impot_c2              numeric,
  tmi                   integer,             -- Tranche Marginale d'Imposition (0, 11, 30, 41, 45)
  rfr                   numeric,             -- Revenu Fiscal de Référence

  -- Banques principales
  banques               text,

  -- Patrimoine structuré (JSONB)
  epargne               jsonb default '{}',
  immobilier            jsonb default '[]',
  credits               jsonb default '[]'
);

-- ── DOCUMENTS (pièces justificatives Storage) ──────────────
create table documents (
  id            uuid primary key default gen_random_uuid(),
  client_id     uuid references clients(id) on delete cascade,
  type          text,
  nom_fichier   text,
  storage_path  text,
  taille_ko     integer,
  date_upload   timestamptz default now(),
  valide        boolean default false
);

-- ── RENDEZ-VOUS ────────────────────────────────────────────
create table rdv (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid references clients(id) on delete cascade,
  date_rdv         timestamptz,
  type             text,
  support          text,
  compte_rendu     text,
  prochaine_action text,
  date_relance     date,
  statut           text default 'planifie',
  created_at       timestamptz default now()
);

-- ── INTERACTIONS (timeline client) ─────────────────────────
create table interactions (
  id                uuid primary key default gen_random_uuid(),
  client_id         uuid references clients(id) on delete cascade,
  date_interaction  timestamptz default now(),
  type              text,    -- RDV / Appel / Email / SMS / Note
  support           text,
  resume            text,
  decisions         text,
  prochaine_etape   text,
  date_relance      date,
  created_at        timestamptz default now()
);

-- ── ÉCHÉANCES (rappels métier) ─────────────────────────────
create table echeances (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid references clients(id) on delete cascade,
  titre           text not null,
  type            text,
  date_echeance   date not null,
  statut          text default 'a_faire',
  notes           text,
  created_at      timestamptz default now()
);

-- ── PROJETS (pipeline R1 / R2 / R3) ────────────────────────
create table projets (
  id                uuid primary key default gen_random_uuid(),
  client_id         uuid references clients(id) on delete cascade,
  statut            text default 'r1' check (statut in ('r1','r2','r3','signe','clos')),
  objectif_projet   text,
  notes_generales   text,
  r1_date           date,
  r1_notes          text,
  r1_decisions      text,
  r1_next           text,
  r2_date           date,
  r2_notes          text,
  r2_decisions      text,
  r2_next           text,
  r3_date           date,
  r3_notes          text,
  r3_decisions      text,
  r3_next           text,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);

-- ── BILANS PATRIMONIAUX ────────────────────────────────────
create table bilans (
  id                  uuid primary key default gen_random_uuid(),
  client_id           uuid references clients(id) on delete cascade,
  date_bilan          date default current_date,
  profil_risque       text,
  horizon             text,
  objectif            text,
  analyse_conseiller  text,
  preconisations      jsonb default '[]',
  objectifs_client    text,
  created_at          timestamptz default now()
);

-- ── MISSIONS (devis / facturation) ─────────────────────────
create table missions (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid references clients(id) on delete cascade,
  type            text not null,
  description     text,
  montant_ht      numeric default 0,
  commission      numeric default 0,
  statut          text default 'devis'
                  check (statut in ('devis','signe','en_cours','livre','facture','paye')),
  date_signature  date,
  date_livraison  date,
  date_paiement   date,
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ── PRODUITS CLIENT (souscriptions) ────────────────────────
create table produits_client (
  id                 uuid primary key default gen_random_uuid(),
  client_id          uuid not null references clients(id) on delete cascade,
  categorie          text not null,
  produit            text,
  prestataire        text,
  montant            numeric,
  date_souscription  date,
  statut             text default 'actif' check (statut in ('actif','clos','en_cours')),
  notes              text,
  created_at         timestamptz default now()
);

-- ── CONFORMITÉ (CIF / AMF / ACPR) ──────────────────────────
create table conformite (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid not null references clients(id) on delete cascade,
  type            text not null,    -- DER, déclaration d'adéquation, mandat, rapport périodique…
  date_remise     date,
  date_expiration date,
  version         text,
  statut          text default 'remis' check (statut in ('remis','signe','a_renouveler')),
  lien_drive      text,
  notes           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ── CLIENT_EMAILS (journal des envois) ─────────────────────
create table client_emails (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid references clients(id) on delete cascade,
  sent_at     timestamptz default now(),
  subject     text,
  type        text,             -- confirmation / rappel / rdv / bilan…
  to_email    text,
  body_html   text,
  created_at  timestamptz default now()
);

-- ── SETTINGS (singletons : clés API, config) ───────────────
-- ⚠ Contient brevo_api_key. À sécuriser impérativement.
create table settings (
  key    text primary key,
  value  text not null
);


-- ══════════════════════════════════════════════════════════
-- TABLES SEO (agent SEO autonome)
-- ══════════════════════════════════════════════════════════

create table seo_topics (
  id                     uuid primary key default gen_random_uuid(),
  titre                  text not null,
  description            text,
  mot_cle_principal      text not null,
  mots_cles_secondaires  text[] default '{}',
  volume_estime          text,
  priorite               text default 'normale' check (priorite in ('haute','normale','basse')),
  statut                 text default 'suggestion'
                         check (statut in ('suggestion','approuve','refuse','genere')),
  source                 text default 'agent',
  created_at             timestamptz default now()
);

create table seo_articles (
  id                     uuid primary key default gen_random_uuid(),
  topic_id               uuid references seo_topics(id),
  titre_seo              text not null,
  meta_description       text,
  slug                   text not null unique,
  contenu_markdown       text,
  mots_cles_secondaires  text[] default '{}',
  suggestions_maillage   text[] default '{}',
  statut                 text default 'brouillon'
                         check (statut in ('brouillon','approuve','publie','archive')),
  notes                  text,
  created_at             timestamptz default now(),
  updated_at             timestamptz default now()
);

create table seo_audits (
  id              uuid primary key default gen_random_uuid(),
  url             text not null,
  titre_actuel    text,
  meta_actuelle   text,
  titre_suggere   text,
  meta_suggeree   text,
  ameliorations   jsonb default '[]',
  statut          text default 'en_attente' check (statut in ('en_attente','applique','ignore')),
  created_at      timestamptz default now()
);


-- ══════════════════════════════════════════════════════════
-- FONCTIONS & TRIGGERS
-- ══════════════════════════════════════════════════════════

create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path to ''
as $$ begin new.updated_at = now(); return new; end; $$;

create or replace function update_updated_at()
returns trigger
language plpgsql
set search_path to ''
as $$ begin new.updated_at = now(); return new; end; $$;

create trigger clients_updated_at  before update on clients  for each row execute function set_updated_at();
create trigger missions_updated_at before update on missions for each row execute function set_updated_at();
create trigger projets_updated_at  before update on projets  for each row execute function set_updated_at();
create trigger seo_articles_updated_at before update on seo_articles for each row execute function update_updated_at();

-- ── notify_make_new_client : email confirmation client + sync Brevo ─
-- Lit la clé Brevo dans le Vault (SECURITY DEFINER requis).
create or replace function notify_make_new_client()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  api_key text;
  prenom  text := coalesce(NEW.prenom_c1, '');
  nom     text := coalesce(NEW.nom_c1, '');
  email   text := NEW.email_c1;
  html    text;
  subject text;
begin
  select decrypted_secret into api_key from vault.decrypted_secrets where name = 'brevo_api_key';

  if NEW.source = 'fiche' then
    subject := 'Votre dossier a bien été reçu — Proactifs Conseils Patrimoine';
    html := '<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#2c3e50">'
      || '<div style="background:#1a2e4a;padding:20px 30px;border-radius:8px 8px 0 0">'
      || '<h2 style="color:#c9a84c;margin:0;font-size:18px">Proactifs Conseils Patrimoine</h2></div>'
      || '<div style="padding:30px;background:#fff;border:1px solid #dde3ed;border-top:none;border-radius:0 0 8px 8px">'
      || '<p>Bonjour ' || prenom || ',</p>'
      || '<p>Merci d''avoir complété votre fiche patrimoniale. Votre dossier a bien été enregistré et je reviendrai vers vous dans les meilleurs délais pour fixer un rendez-vous.</p>'
      || '<p>En attendant, je vous invite à visiter notre site web :</p>'
      || '<p style="text-align:center;margin:24px 0"><a href="https://www.proactifs-conseils.fr" style="background:#c9a84c;color:#1a2e4a;padding:12px 28px;border-radius:6px;text-decoration:none;font-weight:bold">Découvrir nos services →</a></p>'
      || '<p>À très bientôt,</p>'
      || '<p><strong>Medy Matima</strong><br>Proactifs Conseils Patrimoine<br>📞 06 83 86 00 98</p>'
      || '</div></div>';

    perform net.http_post(
      url     := 'https://api.brevo.com/v3/smtp/email',
      headers := jsonb_build_object('api-key', api_key, 'Content-Type', 'application/json'),
      body    := jsonb_build_object(
        'sender',      jsonb_build_object('name', 'Medy Matima — Proactifs Conseils Patrimoine', 'email', 'medymatima@proactifsconseils.fr'),
        'to',          jsonb_build_array(jsonb_build_object('email', email, 'name', prenom || ' ' || nom)),
        'subject',     subject,
        'htmlContent', html
      )
    );

    insert into client_emails (client_id, subject, type, to_email, body_html)
    values (NEW.id, subject, 'confirmation', email, html);
  end if;

  perform net.http_post(
    url     := 'https://api.brevo.com/v3/contacts',
    headers := jsonb_build_object('api-key', api_key, 'Content-Type', 'application/json'),
    body    := jsonb_build_object(
      'email', email, 'updateEnabled', true, 'listIds', jsonb_build_array(22),
      'attributes', jsonb_build_object('PRENOM', prenom, 'NOM', nom,
        'SMS', coalesce(NEW.telephone_c1,''), 'SOURCE', coalesce(NEW.source,'crm'))
    )
  );

  return NEW;
exception when others then
  return NEW;
end;
$$;

create trigger on_new_client_notify
  after insert on clients
  for each row
  when (new.email_c1 is not null and new.email_c1 <> '')
  execute function notify_make_new_client();

-- ── send_reminders : appelée par cron (rappels J-1 et J-7) ──
-- Lit la clé Brevo dans le Vault (SECURITY DEFINER requis).
create or replace function send_reminders()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  api_key   text;
  rec       record;
  prenom    text;
  nom       text;
  html_client text;
  html_medy   text;
  delai     text;
  subject_c text;
  nb_sent   int := 0;
  summary   text := '';
begin
  select decrypted_secret into api_key from vault.decrypted_secrets where name = 'brevo_api_key';

  for rec in
    select e.*, c.email_c1, c.prenom_c1, c.nom_c1, c.telephone_c1
    from echeances e
    join clients c on c.id = e.client_id
    where e.statut = 'a_faire'
      and c.email_c1 is not null
      and (e.date_echeance = current_date + 7 or e.date_echeance = current_date + 1)
  loop
    prenom    := coalesce(rec.prenom_c1, '');
    nom       := coalesce(rec.nom_c1, '');
    delai     := case when rec.date_echeance = current_date + 1 then 'demain' else 'dans 7 jours' end;
    subject_c := '📅 Rappel rendez-vous ' || delai || ' — Proactifs Conseils Patrimoine';

    html_client := '<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#2c3e50">'
      || '<div style="background:#1a2e4a;padding:20px 30px;border-radius:8px 8px 0 0">'
      || '<h2 style="color:#c9a84c;margin:0;font-size:18px">Proactifs Conseils Patrimoine</h2></div>'
      || '<div style="padding:30px;background:#fff;border:1px solid #dde3ed;border-top:none;border-radius:0 0 8px 8px">'
      || '<p>Bonjour ' || prenom || ',</p>'
      || '<p>Rappel : rendez-vous prévu <strong>' || delai || '</strong> — <strong>' || rec.titre || '</strong>.</p>'
      || '<p>Contactez-moi si vous souhaitez modifier la date.</p>'
      || '<p><strong>Medy Matima</strong><br>📞 06 83 86 00 98</p>'
      || '</div></div>';

    perform net.http_post(
      url     := 'https://api.brevo.com/v3/smtp/email',
      headers := jsonb_build_object('api-key', api_key, 'Content-Type', 'application/json'),
      body    := jsonb_build_object(
        'sender', jsonb_build_object('name','Medy Matima — Proactifs Conseils Patrimoine','email','medymatima@proactifsconseils.fr'),
        'to',     jsonb_build_array(jsonb_build_object('email', rec.email_c1, 'name', prenom||' '||nom)),
        'subject', subject_c, 'htmlContent', html_client
      )
    );

    insert into client_emails (client_id, subject, type, to_email, body_html)
    values (rec.client_id, subject_c, 'rappel', rec.email_c1, html_client);

    nb_sent := nb_sent + 1;
    summary := summary || '• ' || prenom || ' ' || nom || ' — ' || rec.titre || ' (' || delai || ')' || E'\n';
  end loop;

  if nb_sent > 0 then
    html_medy := '<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto">'
      || '<div style="background:#1a2e4a;padding:20px 30px;border-radius:8px 8px 0 0">'
      || '<h2 style="color:#c9a84c;margin:0">CRM Proactifs — Récap rappels</h2></div>'
      || '<div style="padding:30px;background:#fff;border:1px solid #dde3ed;border-top:none;border-radius:0 0 8px 8px">'
      || '<p>Bonjour Medy,</p><p>' || nb_sent || ' rappel(s) envoyé(s) ce matin :</p>'
      || '<div style="background:#f4f6f9;border-radius:6px;padding:14px;margin:16px 0;line-height:2">'
      || replace(summary, E'\n', '<br>') || '</div>'
      || '<p><a href="https://crm-proactifs.vercel.app" style="color:#1a2e4a;font-weight:700">Ouvrir le CRM</a></p>'
      || '</div></div>';
    perform net.http_post(
      url     := 'https://api.brevo.com/v3/smtp/email',
      headers := jsonb_build_object('api-key', api_key, 'Content-Type', 'application/json'),
      body    := jsonb_build_object(
        'sender', jsonb_build_object('name','CRM Proactifs','email','medymatima@proactifsconseils.fr'),
        'to',     jsonb_build_array(jsonb_build_object('email','medymatima@gmail.com','name','Medy Matima')),
        'subject', '📅 ' || nb_sent || ' rappel(s) envoyé(s) — CRM Proactifs',
        'htmlContent', html_medy
      )
    );
  end if;
end;
$$;


-- ══════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ⚠ État ACTUEL en production — pas l'état souhaité.
-- Les corrections sont dans remediation-rls.sql.
-- ══════════════════════════════════════════════════════════

alter table clients         enable row level security;
alter table documents       enable row level security;
alter table rdv             enable row level security;
alter table interactions    enable row level security;
alter table echeances       enable row level security;
alter table projets         enable row level security;
alter table bilans          enable row level security;
alter table missions        enable row level security;
alter table produits_client enable row level security;
alter table conformite      enable row level security;
alter table client_emails   enable row level security;
alter table settings        enable row level security;

alter table seo_topics   enable row level security;
alter table seo_articles enable row level security;
alter table seo_audits   enable row level security;

-- Formulaire public — INSERT depuis fiche-client.html
create policy "insert_open"        on clients   for insert to public with check (true);
create policy "insert_open_docs"   on documents for insert to public with check (true);

-- CRM authenticated (non-anonyme) — accès complet
create policy "crm_clients_all"      on clients         for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_documents_all"    on documents       for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_rdv_all"          on rdv             for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_interactions_all" on interactions    for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_echeances_all"    on echeances       for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_projets_all"      on projets         for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_bilans_all"       on bilans          for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_missions_all"     on missions        for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_emails_all"       on client_emails   for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_conformite_all"   on conformite      for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "crm_produits_client_all" on produits_client for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);

-- Settings — lecture et écriture pour les users réels uniquement
create policy "settings_read_real_users"  on settings for select to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true);
create policy "settings_write_real_users" on settings for all to authenticated using ((auth.jwt() ->> 'is_anonymous')::boolean is not true) with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);

-- ══════════════════════════════════════════════════════════
-- STORAGE — bucket "documents"
-- ══════════════════════════════════════════════════════════
-- create bucket via console : Storage > New bucket > "documents" > Public: NON

create policy "upload_public_documents" on storage.objects
  for insert to anon
  with check (bucket_id = 'documents');

create policy "crm_storage_all" on storage.objects
  for all to authenticated
  using (bucket_id = 'documents')
  with check (bucket_id = 'documents');
