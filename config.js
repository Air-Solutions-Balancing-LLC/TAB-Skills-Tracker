// ============================================
// CONFIGURACION DE SUPABASE
// Reemplaza estos valores con los tuyos
// ============================================

const SUPABASE_URL = 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_KEY = 'sb_publishable_hh7_CD_TuH0X3YugPn_Z6w_VWSAAvlb';

// Regiones disponibles
const REGIONS = ['RM', 'SW', 'SE', 'National', 'Survey'];

const REGION_LABELS = {
  RM: 'Rocky Mountain',
  SW: 'Southwest',
  SE: 'Southeast',
  National: 'National',
  Survey: 'Survey'
};

// Categorias de habilidades (escala 1-5)
const SKILL_CATEGORIES = [
  { key: 'safety_avg',        label: 'Safety / Core Values' },
  { key: 'basic_avg',         label: 'Basic'                },
  { key: 'intermediate_avg',  label: 'Intermediate'         },
  { key: 'advanced_avg',      label: 'Advanced'             },
  { key: 'survey_avg',        label: 'TAB Survey'           }
];
