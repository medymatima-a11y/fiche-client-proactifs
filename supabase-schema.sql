-- ══════════════════════════════════════════════════════════
-- CRM Proactifs Conseils Patrimoine — Schéma Supabase
-- Coller et exécuter dans : Supabase > SQL Editor > New query
-- ══════════════════════════════════════════════════════════

-- ── CLIENTS ────────────────────────────────────────────────
create table clients (
  id                    uuid primary key default gen_random_uuid(),
  created_at            timestamptz default now(),
  updated_at            timestamptz default now(),

  -- Statut CRM
  statut                text default 'prospect'
                        check (statut in ('prospect','actif','inactif','archive')),
  date_entree           date default current_date,
  notes                 text,

  -- Conjoint 1
  nom_c1                text,
  prenom_c1             text,
  date_naissance_c1     date,
  lieu_naissance_c1     text,
  telephone_c1          text,
  email_c1              text,
  profession_c1         text,
  entreprise_c1         text,

  -- Conjoint 2
  nom_c2                text,
  prenom_c2             text,
  date_naissance_c2     date,
  lieu_naissance_c2     text,
  telephone_c2          text,
  email_c2              text,
  profession_c2         text,
  entreprise_c2         text,

  -- Adresse
  adresse               text,

  -- Situation familiale
  statut_marital        text,
  regime                text,
  date_union            date,
  enfants_noms          text,
  enfants_dob           text,

  -- Revenus
  salaire_c1            numeric,
  salaire_c2            numeric,
  impot_c1              numeric,
  impot_c2              numeric,

  -- Banques
  banques               text,

  -- Données structurées (JSONB)
  epargne               jsonb default '{}',
  immobilier            jsonb default '[]',
  credits               jsonb default '[]'
);

-- ── DOCUMENTS ──────────────────────────────────────────────
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

-- ── BILANS PATRIMONIAUX ────────────────────────────────────
create table bilans (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid references clients(id) on delete cascade,
  date_bilan       date default current_date,
  profil_risque    text,
  horizon          text,
  objectif         text,
  analyse          text,
  preconisations   jsonb default '[]',
  objectifs_client text,
  created_at       timestamptz default now()
);

-- ── TRIGGER updated_at ─────────────────────────────────────
create or replace function set_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger clients_updated_at
  before update on clients
  for each row execute function set_updated_at();

-- ══════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ══════════════════════════════════════════════════════════
alter table clients   enable row level security;
alter table documents enable row level security;
alter table rdv       enable row level security;
alter table bilans    enable row level security;

-- Formulaire public : les clients peuvent envoyer leur fiche (INSERT only)
create policy "Fiche publique insert" on clients
  for insert to anon with check (true);

create policy "Documents publics insert" on documents
  for insert to anon with check (true);

-- CRM (Medy authentifié) : accès complet
create policy "CRM acces clients" on clients
  for all to authenticated using (true) with check (true);

create policy "CRM acces documents" on documents
  for all to authenticated using (true) with check (true);

create policy "CRM acces rdv" on rdv
  for all to authenticated using (true) with check (true);

create policy "CRM acces bilans" on bilans
  for all to authenticated using (true) with check (true);

-- ══════════════════════════════════════════════════════════
-- STORAGE — bucket "documents"
-- À créer manuellement dans : Storage > New bucket
-- Nom : documents | Public : NON
-- Puis ajouter ces policies dans Storage > Policies
-- ══════════════════════════════════════════════════════════

-- Policy Storage anon INSERT (pour la fiche publique)
-- insert into storage.buckets (id, name) values ('documents', 'documents');

create policy "Upload public documents" on storage.objects
  for insert to anon
  with check (bucket_id = 'documents');

create policy "CRM acces storage" on storage.objects
  for all to authenticated
  using (bucket_id = 'documents')
  with check (bucket_id = 'documents');
