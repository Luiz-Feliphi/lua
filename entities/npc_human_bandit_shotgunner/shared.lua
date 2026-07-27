ENT.Base = "base_ai"
ENT.Type = "ai"
  
ENT.PrintName = "Bandit"
ENT.Author = "gumlefar"
ENT.Contact = ""
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Information	= ""  
ENT.Category		= ""

ENT.AutomaticFrameAdvance = true
   
ENT.Spawnable = false
ENT.AdminSpawnable = false

function ENT:SetAutomaticFrameAdvance( bUsingAnim )
  self.AutomaticFrameAdvance = bUsingAnim
end

-- ============================================================
-- FIX: T-pose / "ice-skating" (pes deslizando) em NPCs base_ai
-- ============================================================
-- Diagnostico: quando o modelo (bandit_regulare.mdl, etc.) nao tem
-- uma sequencia compilada para a Activity que o AI esta pedindo
-- (ex: ACT_RANGE_ATTACK1 com o SWEP de pistola, ou ACT_WALK/ACT_RUN),
-- o engine nao acha nenhuma sequencia valida e o modelo congela na
-- bind pose (T-pose) enquanto o NPC continua se movendo pelo mundo
-- (o que aparenta os "pes colados/deslizando no chao").
--
-- Este bloco:
-- 1) Tenta uma lista de Activities alternativas ANTES de deixar o
--    NPC travar em T-pose, para as ACTs mais comuns que costumam
--    faltar em modelos reskinados/playermodels.
-- 2) Loga no console do servidor (sv_bandit_debug_anim 1) qual ACT
--    esta faltando e em qual modelo, para voce identificar com
--    certeza se o problema e a Activity X ou Y no .mdl.
-- ============================================================

if not ConVarExists( "sv_bandit_debug_anim" ) then
  CreateConVar( "sv_bandit_debug_anim", "0", FCVAR_ARCHIVE, "1 = loga no console quais Activities estao faltando nos modelos dos bandits" )
end

-- Os modelos STALKER (flaymi/Anomaly) usam a familia de animacao
-- ACT_HL2MP_* (a mesma do HL2 Deathmatch: idle/andar/correr/atirar
-- por tipo de arma), NAO a familia classica de NPC (ACT_WALK,
-- ACT_RANGE_ATTACK1, etc.) que o base_ai pede automaticamente.
-- Por isso mapeamos cada ACT pedida pra sua equivalente ACT_HL2MP_*
-- de acordo com o HoldType desta classe (definido no init.lua:
-- "pistol", "smg", "ar2" ou "shotgun").
local HL2MP_IDLE_BY_HOLD = {
  pistol  = ACT_HL2MP_IDLE_PISTOL,
  smg     = ACT_HL2MP_IDLE_SMG1,
  ar2     = ACT_HL2MP_IDLE_AR2,
  shotgun = ACT_HL2MP_IDLE_SHOTGUN,
}
local HL2MP_WALK_BY_HOLD = {
  pistol  = ACT_HL2MP_WALK_PISTOL,
  smg     = ACT_HL2MP_WALK_SMG1,
  ar2     = ACT_HL2MP_WALK_AR2,
  shotgun = ACT_HL2MP_WALK_SHOTGUN,
}
local HL2MP_RUN_BY_HOLD = {
  pistol  = ACT_HL2MP_RUN_PISTOL,
  smg     = ACT_HL2MP_RUN_SMG1,
  ar2     = ACT_HL2MP_RUN_AR2,
  shotgun = ACT_HL2MP_RUN_SHOTGUN,
}
local HL2MP_ATTACK_BY_HOLD = {
  pistol  = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL,
  smg     = ACT_HL2MP_GESTURE_RANGE_ATTACK_SMG1,
  ar2     = ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2,
  shotgun = ACT_HL2MP_GESTURE_RANGE_ATTACK_SHOTGUN,
}
local HL2MP_RELOAD_BY_HOLD = {
  pistol  = ACT_HL2MP_GESTURE_RELOAD_PISTOL,
  smg     = ACT_HL2MP_GESTURE_RELOAD_SMG1,
  ar2     = ACT_HL2MP_GESTURE_RELOAD_AR2,
  shotgun = ACT_HL2MP_GESTURE_RELOAD_SHOTGUN,
}

-- Ordem de holds pra tentar em cascata: se o hold "ideal" da classe
-- nao existir no .mdl (ex: modelo so foi compilado com animacao de
-- pistola), tenta os proximos da lista antes de desistir.
local HOLD_FALLBACK_ORDER = {
  pistol  = { "pistol" },
  smg     = { "smg", "pistol" },
  ar2     = { "ar2", "smg", "pistol" },
  shotgun = { "shotgun", "smg", "pistol" },
}

-- Categoria de "flinch" (reacao de dor ao tomar dano). O engine pede
-- alguma dessas ACT automaticamente quando o NPC leva um tiro. Esses
-- modelos NAO tem animacao de flinch dedicada, entao mapeamos pra
-- pose de idle armado do hold (garantido que existe) em vez de
-- deixar cair em T-pose.
local FLINCH_ACTIVITIES = {
  ACT_SMALL_FLINCH, ACT_BIG_FLINCH,
  ACT_FLINCH_HEAD, ACT_FLINCH_CHEST, ACT_FLINCH_STOMACH,
  ACT_FLINCH_LEFTARM, ACT_FLINCH_RIGHTARM,
  ACT_FLINCH_LEFTLEG, ACT_FLINCH_RIGHTLEG,
  ACT_FLINCH_PHYSICS,
}
local IS_FLINCH_ACTIVITY = {}
for _, a in ipairs( FLINCH_ACTIVITIES ) do
  IS_FLINCH_ACTIVITY[ a ] = true
end

-- Fallbacks genericos (usados so se nem a familia HL2MP nem a
-- classica de NPC forem encontradas -- ultimo recurso).
ENT.ActivityFallbacks = {
  [ACT_RANGE_ATTACK1] = { ACT_RANGE_ATTACK_SMG1, ACT_RANGE_ATTACK_AR2, ACT_RANGE_ATTACK_SHOTGUN, ACT_RANGE_ATTACK_PISTOL, ACT_IDLE_ANGRY },
  [ACT_RANGE_ATTACK2] = { ACT_RANGE_ATTACK1 },
  [ACT_RELOAD]         = { ACT_RELOAD_SMG1, ACT_RELOAD_PISTOL, ACT_IDLE },
  [ACT_WALK]           = { ACT_WALK_AIM_RIFLE, ACT_WALK_AIM_PISTOL, ACT_RUN, ACT_IDLE },
  [ACT_RUN]            = { ACT_RUN_AIM_RIFLE, ACT_RUN_AIM_PISTOL, ACT_WALK, ACT_IDLE },
  [ACT_IDLE]           = { ACT_IDLE_ANGRY, ACT_IDLE_RELAXED },
  [ACT_COWER]          = { ACT_IDLE },
  [ACT_CROUCHIDLE]     = { ACT_IDLE },
}
for _, a in ipairs( FLINCH_ACTIVITIES ) do
  ENT.ActivityFallbacks[ a ] = { ACT_IDLE_ANGRY, ACT_IDLE }
end

-- Forca a pose de tiro certa na entidade diretamente, no exato
-- momento em que o ataque comeca. Isso contorna qualquer traducao
-- de animacao que a propria SWEP da arma (weapon_npc_*) possa estar
-- fazendo por conta propria e ignorando o nosso TranslateActivity
-- (o que causa T-pose na hora de atirar mesmo com o fallback certo
-- configurado aqui).
function ENT:ForceAttackPose()
  local act = self:TranslateActivity( ACT_RANGE_ATTACK1 )
  local seq = self:SelectWeightedSequence( act )
  if seq != -1 then
    self:ResetSequence( seq )
    self.ForcedAttackSeq = seq
    -- mantem essa pose por 1s (chamado todo Think enquanto durar),
    -- tempo de sobra pra cobrir a animacao de tiro mesmo se a SWEP
    -- da arma tentar sobrescrever a sequencia no proprio Think dela.
    self.ForceAttackPoseUntil = CurTime() + 1
  end
end

-- Chamado todo Think(). Se a SWEP da arma reescrever a sequencia
-- por conta propria (causando T-pose) durante a janela de tiro,
-- a gente reafirma a sequencia certa de volta no proximo tick.
function ENT:MaintainAttackPose()
  if self.ForceAttackPoseUntil and CurTime() < self.ForceAttackPoseUntil and self.ForcedAttackSeq then
    if self:GetSequence() != self.ForcedAttackSeq then
      self:ResetSequence( self.ForcedAttackSeq )
    end
  end
end

function ENT:TranslateActivity( act )
  -- Se o modelo tem a sequencia certa pra essa ACT exata, usa normalmente.
  if self:SelectWeightedSequence( act ) != -1 then
    return act
  end

  local hold = self.HoldType or "pistol"
  local holdOrder = HOLD_FALLBACK_ORDER[ hold ] or { "pistol" }
  local fallbacks = {}

  -- 1) Prioriza a familia ACT_HL2MP_* certa, em cascata: tenta o
  --    hold ideal da classe primeiro, depois os proximos da lista
  --    (ex: rifleman tenta ar2 -> smg -> pistol) ate achar um que
  --    o .mdl realmente tenha compilado.
  local byHoldTable
  if act == ACT_WALK then
    byHoldTable = HL2MP_WALK_BY_HOLD
  elseif act == ACT_RUN then
    byHoldTable = HL2MP_RUN_BY_HOLD
  elseif act == ACT_IDLE or act == ACT_CROUCHIDLE or act == ACT_COWER or IS_FLINCH_ACTIVITY[ act ] then
    byHoldTable = HL2MP_IDLE_BY_HOLD
  elseif act == ACT_RANGE_ATTACK1 or act == ACT_RANGE_ATTACK2 then
    byHoldTable = HL2MP_ATTACK_BY_HOLD
  elseif act == ACT_RELOAD then
    byHoldTable = HL2MP_RELOAD_BY_HOLD
  end

  if byHoldTable then
    for _, h in ipairs( holdOrder ) do
      table.insert( fallbacks, byHoldTable[ h ] )
    end
  end

  -- 2) Depois tenta os fallbacks classicos de NPC (modelos antigos).
  local classicFallbacks = self.ActivityFallbacks[ act ]
  if classicFallbacks then
    for _, fb in ipairs( classicFallbacks ) do
      table.insert( fallbacks, fb )
    end
  end

  for _, fb in ipairs( fallbacks ) do
    if fb and self:SelectWeightedSequence( fb ) != -1 then
      if GetConVar( "sv_bandit_debug_anim" ):GetBool() then
        print( string.format( "[BanditAI] %s (%s): ACT %s ausente, usando fallback %s (hold=%s)", self:GetClass(), self:GetModel(), tostring(act), tostring(fb), hold ) )
      end
      return fb
    end
  end

  -- Nenhum fallback funcionou: loga pra voce saber exatamente o que falta no .mdl.
  if GetConVar( "sv_bandit_debug_anim" ):GetBool() then
    print( string.format( "[BanditAI] AVISO: %s (%s) NAO tem nenhuma sequencia para ACT %s nem fallback -> vai T-posar", self:GetClass(), self:GetModel(), tostring(act) ) )
  end

  return act
end