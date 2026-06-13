-- ══════════════════════════════════════════════════════════
-- MIGRATION : prospects_linkedin
-- Appliquée le 2026-06-13 sur le projet ullnkylrixdvormohryl
-- Intègre cette migration dans supabase-schema.sql à la fin.
-- ══════════════════════════════════════════════════════════

-- ── TABLE : prospects_linkedin ─────────────────────────────
-- Pipeline de prospection LinkedIn (Kanban 7 étapes × 3 segments).
-- Partagée entre :
--   · dashboard-prospection.html (Kanban frontend, accès anon)
--   · Agent quotidien prospection (scheduled task 8h02 lun-ven)
-- FK optionnelle vers clients.id pour le suivi de conversion.

create table if not exists prospects_linkedin (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz default now(),
  updated_at        timestamptz default now(),

  -- Identité
  prenom            text not null,
  nom               text not null,
  poste             text,
  entreprise        text,
  linkedin_url      text,

  -- Segmentation ICP
  segment           text check (segment in ('A','B','C')),
  -- A = Dirigeants PME/TPE
  -- B = Cadres Tech / RSU / BSPCE
  -- C = Professions libérales

  -- Pipeline Kanban (7 étapes)
  stage             integer default 1 check (stage between 1 and 7),
  -- 1 = À contacter
  -- 2 = Demande de connexion envoyée
  -- 3 = Connecté / à envoyer J+1
  -- 4 = Message J+1 envoyé / attente J+7
  -- 5 = En conversation
  -- 6 = RDV programmé
  -- 7 = Converti / Clos

  -- Dates clés (pour alertes J+7 et calcul délai)
  date_connexion    date,
  date_message_j1   date,
  date_relance_j7   date,
  date_rdv          date,

  -- Messages préparés (semi-auto : Medy envoie manuellement)
  message_connexion text,   -- ≤300 caractères (note de connexion LinkedIn)
  message_j1        text,   -- message post-connexion J+1
  message_relance   text,   -- relance J+7

  -- Enrichissement email
  email             text,
  email_verifie     boolean default false,
  hunter_list_id    integer,  -- ID de la liste Hunter.io (12198766=A, 12198767=B, 12198768=C)
  apollo_enriched   boolean default false,

  -- Traçabilité source
  source_scan       text,     -- 'manuel' | 'post_perfect_liker' | 'post_perfect_commenter' | 'agent'
  post_source_url   text,     -- URL du post LinkedIn qui a généré le prospect

  -- Brevo
  brevo_contact_id  text,
  brevo_sequence    text,

  -- Lien CRM (conversion client)
  client_id         uuid references clients(id) on delete set null,

  -- Gestion
  notes             text,
  statut            text default 'actif' check (statut in ('actif','pause','archive'))
);

-- Trigger updated_at (réutilise set_updated_at() déjà définie)
create trigger prospects_linkedin_updated_at
  before update on prospects_linkedin
  for each row execute function set_updated_at();

-- RLS
alter table prospects_linkedin enable row level security;

-- CRM authenticated (non-anonyme) — accès complet
create policy "crm_prospects_linkedin_all"
  on prospects_linkedin for all to authenticated
  using  ((auth.jwt() ->> 'is_anonymous')::boolean is not true)
  with check ((auth.jwt() ->> 'is_anonymous')::boolean is not true);

-- Accès anon pour le Kanban dashboard-prospection.html
-- (données marketing uniquement, pas de données financières clients)
create policy "kanban_anon_all"
  on prospects_linkedin for all to anon
  using (true)
  with check (true);

-- ── VUE : alertes J+7 pour l'agent quotidien ──────────────
create or replace view v_prospects_j7_a_relancer as
  select
    id, prenom, nom, poste, entreprise, linkedin_url,
    segment, stage,
    date_connexion,
    (current_date - date_connexion) as jours_depuis_connexion,
    message_relance, email, notes
  from prospects_linkedin
  where stage = 4
    and statut = 'actif'
    and date_connexion is not null
    and (current_date - date_connexion) between 6 and 9;

-- ══════════════════════════════════════════════════════════
-- FIN MIGRATION prospects_linkedin
-- ══════════════════════════════════════════════════════════
