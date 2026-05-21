// ── Déploiement Vercel via API REST ─────────────────────────
// Lance avec : node deploy-vercel.js
const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const TOKEN  = process.env.VERCEL_TOKEN;
const ORG_ID = 'team_9NQXn7SAi0IfcpP9AjqsVBKI';

const PROJETS = [
  {
    nom:       'Fiche client',
    projectId: 'prj_xkIVTDHM8AALoIQJ52pBe50KP3kK',
    fichier:   path.join(__dirname, 'deploy', 'index.html'),
    dashboard: 'https://vercel.com/medymatima-a11ys-projects/deploy',
  },
  {
    nom:       'CRM',
    projectId: 'prj_aBPBvxhcfdrMdH5BYr9M8qx8tW1B',
    fichier:   path.join(__dirname, 'deploy-crm', 'index.html'),
    dashboard: 'https://vercel.com/medymatima-a11ys-projects/deploy-crm',
  },
];

function uploadFichier(content, sha1) {
  return new Promise((resolve, reject) => {
    const buf = Buffer.from(content, 'utf8');
    const options = {
      hostname: 'api.vercel.com',
      path: '/v2/files',
      method: 'POST',
      headers: {
        'Authorization':   `Bearer ${TOKEN}`,
        'Content-Type':    'application/octet-stream',
        'Content-Length':  buf.length,
        'x-vercel-digest': sha1,
        'x-vercel-team-id': ORG_ID,
      }
    };
    const req = https.request(options, res => {
      let chunks = '';
      res.on('data', d => chunks += d);
      res.on('end', () => resolve({ status: res.statusCode, body: chunks }));
    });
    req.on('error', reject);
    req.write(buf);
    req.end();
  });
}

function creerDeploiement(projectId, nom, sha1, taille) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      name:   nom,
      files:  [{ file: 'index.html', sha: sha1, size: taille }],
      target: 'production',
      projectSettings: {
        framework:       null,
        buildCommand:    null,
        devCommand:      null,
        installCommand:  null,
        outputDirectory: null,
      },
    });
    const options = {
      hostname: 'api.vercel.com',
      path:     `/v13/deployments?forceNew=1&skipAutoDetectionConfirmation=1&projectId=${projectId}&teamId=${ORG_ID}`,
      method:   'POST',
      headers: {
        'Authorization':  `Bearer ${TOKEN}`,
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(payload),
      }
    };
    const req = https.request(options, res => {
      let chunks = '';
      res.on('data', d => chunks += d);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(chunks) }); }
        catch(e) { resolve({ status: res.statusCode, body: chunks }); }
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function deployerProjet(projet) {
  console.log(`\n${'='.repeat(50)}`);
  console.log(`🚀 ${projet.nom}`);
  console.log('='.repeat(50));

  const content = fs.readFileSync(projet.fichier, 'utf8');
  const sha1    = crypto.createHash('sha1').update(content).digest('hex');
  const taille  = Buffer.byteLength(content);
  console.log(`📦 Fichier : ${path.basename(projet.fichier)} (${Math.round(taille/1024)} Ko)`);
  console.log(`   SHA1   : ${sha1}`);

  console.log('⬆️  Upload...');
  const upload = await uploadFichier(content, sha1);
  if (![200, 201, 409].includes(upload.status)) {
    console.error(`❌ Erreur upload (${upload.status}):`, upload.body);
    return false;
  }
  console.log(`   Statut : ${upload.status} ✅`);

  console.log('🔨 Création du déploiement...');
  const dep = await creerDeploiement(
    projet.projectId,
    projet.nom.toLowerCase().replace(/ /g, '-'),
    sha1,
    taille
  );
  if (![200, 201].includes(dep.status)) {
    console.error(`❌ Erreur déploiement (${dep.status}):`, JSON.stringify(dep.body, null, 2));
    return false;
  }

  const url = dep.body.url ? `https://${dep.body.url}` : projet.dashboard;
  console.log(`✅ Déployé ! URL : ${url}`);
  console.log(`   Dashboard : ${projet.dashboard}`);
  return true;
}

async function main() {
  if (!TOKEN) {
    console.error('❌ VERCEL_TOKEN non défini.');
    process.exit(1);
  }

  console.log('🚀 Déploiement CRM Proactifs Conseils');
  console.log(`   ${new Date().toLocaleString('fr-FR')}\n`);

  let success = 0;
  for (const projet of PROJETS) {
    const ok = await deployerProjet(projet);
    if (ok) success++;
  }

  console.log(`\n${'='.repeat(50)}`);
  if (success === PROJETS.length) {
    console.log(`✅ Tous les déploiements réussis (${success}/${PROJETS.length})`);
    process.exit(0);
  } else {
    console.error(`❌ ${PROJETS.length - success} déploiement(s) échoué(s) sur ${PROJETS.length}`);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('❌ Erreur fatale :', err);
  process.exit(1);
});
