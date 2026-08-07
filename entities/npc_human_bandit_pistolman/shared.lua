ENT.Base = "base_ai"
ENT.SeeksCover = true
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

-- Antes usava um ConVar server-side (sv_bandit_debug_anim), mas isso
-- exige acesso ao console do servidor/RCON pra ligar, o que nao
-- funciona pra quem so tem o console do jogo num servidor dedicado.
-- Um concommand digitado no CONSOLE DO CLIENTE (~) e repassado pro
-- servidor automaticamente pelo proprio engine, sem precisar de RCON.
if SERVER then
  BANDIT_DEBUG_ANIM = BANDIT_DEBUG_ANIM or false

  if not concommand.GetTable()[ "bandit_debug_anim" ] then
    concommand.Add( "bandit_debug_anim", function( ply, cmd, args )
      BANDIT_DEBUG_ANIM = ( args[1] != "0" )
      local msg = "[BanditAI] Debug de animacao: " .. ( BANDIT_DEBUG_ANIM and "LIGADO" or "DESLIGADO" )
      print( msg )
      if IsValid( ply ) then
        ply:PrintMessage( HUD_PRINTCONSOLE, msg )
      end
    end )
  end
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

-- ============================================================
-- FIX DEFINITIVO v2: nome exato da sequencia, nao Activity
-- ============================================================
-- Explorando o modelo no HLMV, confirmamos que ele tem sequencias
-- NOMEADAS tipo "shoot_pistol", "shoot_ar2", "shoot_shotgun",
-- "shoot_smg1", "reload_pistol", etc. -- mas elas podem nao ter
-- nenhuma Activity ACT_HL2MP_GESTURE_* associada no .qc, entao
-- SelectWeightedSequence(ACT_...) nunca achava, mesmo a sequencia
-- existindo de verdade no modelo.
--
-- Agora buscamos pelo NOME exato via LookupSequence() e aplicamos
-- via AddGestureSequence() (a mesma logica de gesture/camada de
-- antes, so que endereçando a sequencia diretamente por indice em
-- vez de depender de Activity).
-- ============================================================

local SEQ_NAME_SUFFIX_BY_HOLD = {
  pistol  = "pistol",
  smg     = "smg1",
  ar2     = "ar2",
  shotgun = "shotgun",
}

-- Tenta achar a sequencia certa em cascata pelo NOME, na ordem de
-- hold de fallback da classe (ex: shotgun -> smg1 -> pistol).
function ENT:ResolveHoldSequence( prefix )
  local hold = self.HoldType or "pistol"
  local holdOrder = HOLD_FALLBACK_ORDER[ hold ] or { "pistol" }

  for _, h in ipairs( holdOrder ) do
    local suffix = SEQ_NAME_SUFFIX_BY_HOLD[ h ] or h
    local seq = self:LookupSequence( prefix .. suffix )
    if seq and seq > 0 then
      return seq
    end
  end

  return -1
end

function ENT:PlayGestureSequence( seq )
  if BANDIT_DEBUG_ANIM then
    print( string.format( "[BanditAI] %s: PlayGestureSequence #%d (%s)", self:GetClass(), seq, self:GetSequenceName( seq ) or "?" ) )
  end
  if self._attackGestureLayer then
    self:RemoveGesture( self._attackGestureLayer )
  end
  self._attackGestureLayer = self:AddGestureSequence( seq, true )
  self:SetLayerBlendIn( self._attackGestureLayer, 0.05 )
  self:SetLayerBlendOut( self._attackGestureLayer, 0.05 )
end

function ENT:ForceAttackPose()
  self:TickVirtualAmmo()

  if BANDIT_DEBUG_ANIM then
    print( string.format( "[BanditAI] %s: ForceAttackPose() CHAMADA (hold=%s)", self:GetClass(), tostring(self.HoldType) ) )
  end

  -- 1) Tenta pelo NOME exato da sequencia (ex: "shoot_pistol").
  local seq = self:ResolveHoldSequence( "shoot_" )
  if BANDIT_DEBUG_ANIM then
    print( string.format( "[BanditAI] %s: ForceAttackPose -> ResolveHoldSequence('shoot_') = %s", self:GetClass(), tostring(seq) ) )
  end
  if seq > 0 then
    self:PlayGestureSequence( seq )
    return
  end

  -- 2) Cai pra tentativa por Activity (HL2MP gesture), caso o nome
  --    nao bata mas a Activity exista mesmo assim.
  local hold = self.HoldType or "pistol"
  local holdOrder = HOLD_FALLBACK_ORDER[ hold ] or { "pistol" }
  for _, h in ipairs( holdOrder ) do
    local act = HL2MP_ATTACK_BY_HOLD[ h ]
    if act and self:SelectWeightedSequence( act ) != -1 then
      self:PlayGestureSequence( self:SelectWeightedSequence( act ) )
      return
    end
  end

  -- 3) Ultimo recurso: fallback classico de NPC como sequencia primaria.
  local act = self:TranslateActivity( ACT_RANGE_ATTACK1 )
  local classicSeq = self:SelectWeightedSequence( act )
  if classicSeq != -1 and classicSeq != 0 then
    self:ResetSequence( classicSeq )
  end
end

-- Chamado todo Think() enquanto a janela de tiro estiver ativa.
-- Com gesture, normalmente nao precisa reafirmar nada (a camada
-- fica tocando sozinha), mas mantemos como rede de seguranca caso
-- a gesture seja removida por fora.
function ENT:MaintainAttackPose()
end

-- Irma da ForceAttackPose, mas pra pose de recarregar.
function ENT:ForceReloadPose()
  local seq = self:ResolveHoldSequence( "reload_" )
  if seq > 0 then
    self:PlayGestureSequence( seq )
    return
  end

  local hold = self.HoldType or "pistol"
  local holdOrder = HOLD_FALLBACK_ORDER[ hold ] or { "pistol" }
  for _, h in ipairs( holdOrder ) do
    local act = HL2MP_RELOAD_BY_HOLD[ h ]
    if act and self:SelectWeightedSequence( act ) != -1 then
      self:PlayGestureSequence( self:SelectWeightedSequence( act ) )
      return
    end
  end

  local act = self:TranslateActivity( ACT_RELOAD )
  local classicSeq = self:SelectWeightedSequence( act )
  if classicSeq != -1 and classicSeq != 0 then
    self:ResetSequence( classicSeq )
  end
end

-- ACT_VM_* sao as activities que a PROPRIA ARMA manda tocar (via
-- Weapon:SendWeaponAnim) quando atira/recarrega/troca de arma. Pra
-- nao depender de editar cada weapon_npc_* uma por uma, a gente
-- intercepta essas ACTs aqui tambem e resolve pela mesma cascata de
-- hold -- assim QUALQUER arma que peça uma dessas ja cai pra uma
-- animacao que o modelo realmente tem.
local VM_ACT_TO_CATEGORY = {
  [ACT_VM_PRIMARYATTACK]   = "attack",
  [ACT_VM_SECONDARYATTACK] = "attack",
  [ACT_VM_RELOAD]          = "reload",
  [ACT_VM_IDLE]            = "idle",
  [ACT_VM_DRAW]            = "idle",
  [ACT_VM_DEPLOY]          = "idle",
  [ACT_VM_HOLSTER]         = "idle",
}

-- ============================================================
-- Intercepta SetSchedule(): qualquer codigo (arma, addon, etc.) que
-- tente forcar uma schedule diretamente no NPC por fora do nosso
-- SelectSchedule() passa por aqui primeiro. Schedules conhecidas por
-- pedir animacao que esses modelos nao tem (ex: SCHED_TAKE_COVER_FROM_ENEMY
-- sem node graph no mapa) sao redirecionadas pra uma equivalente que
-- a gente ja sabe que funciona.
-- SO existe no servidor: constantes SCHED_* nao existem no cliente
-- (agendamento de IA e coisa server-side), entao esse bloco quebraria
-- o cliente se rodasse la (table index is nil).
-- ============================================================
if SERVER then
  local NPC_META = FindMetaTable( "NPC" )
  local RealSetSchedule = NPC_META and NPC_META.SetSchedule

  local SCHEDULE_REDIRECTS = {
    [SCHED_TAKE_COVER_FROM_ENEMY] = SCHED_BACK_AWAY_FROM_ENEMY,
  }

  if NPC_META and RealSetSchedule then
    function ENT:SetSchedule( sched )
      local redirect = SCHEDULE_REDIRECTS[ sched ]
      if redirect then
        if BANDIT_DEBUG_ANIM then
          print( string.format( "[BanditAI] %s: SCHED %s redirecionada pra %s (pedida por fora do SelectSchedule)", self:GetClass(), tostring(sched), tostring(redirect) ) )
        end
        sched = redirect
      end
      RealSetSchedule( self, sched )
    end
  end
end

function ENT:TranslateActivity( act )
  -- ACT_VM_* (pedida pela ARMA, nao pelo NPC): traduz pra categoria
  -- equivalente antes de qualquer outra coisa.
  local vmCategory = VM_ACT_TO_CATEGORY[ act ]
  if vmCategory == "attack" then
    act = ACT_RANGE_ATTACK1
  elseif vmCategory == "reload" then
    act = ACT_RELOAD
  elseif vmCategory == "idle" then
    act = ACT_IDLE
  end

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
  --
  -- IMPORTANTE (confirmado no .qc do modelo): as sequencias de tiro
  -- e recarga (shoot_*, reload_*) sao "delta" -- soamdas ADITIVAS,
  -- sem pose de corpo inteiro proprias. Elas SO funcionam como
  -- gesture (camada), nunca como sequencia PRIMARIA. A schedule
  -- classica de ataque (TASK_RANGE_ATTACK1) pede pro engine tocar
  -- ACT_RANGE_ATTACK1 como PRIMARIA -- se a gente traduzisse isso
  -- pra ACT_HL2MP_GESTURE_RANGE_ATTACK_*, o engine tentaria tocar
  -- uma delta sozinha como corpo inteiro = T-pose. Por isso NAO
  -- mapeamos ACT_RANGE_ATTACK1/ACT_RELOAD pra essas aqui: mantemos o
  -- corpo no idle do hold (seguro) e quem cuida do visual do tiro e
  -- SO a ForceAttackPose/ForceReloadPose (via gesture, disparada
  -- pela propria arma), nunca a sequencia primaria.
  local byHoldTable
  if act == ACT_WALK then
    byHoldTable = HL2MP_WALK_BY_HOLD
  elseif act == ACT_RUN then
    byHoldTable = HL2MP_RUN_BY_HOLD
  elseif act == ACT_IDLE or act == ACT_CROUCHIDLE or act == ACT_COWER or IS_FLINCH_ACTIVITY[ act ]
      or act == ACT_RANGE_ATTACK1 or act == ACT_RANGE_ATTACK2 or act == ACT_RELOAD then
    byHoldTable = HL2MP_IDLE_BY_HOLD
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
      if BANDIT_DEBUG_ANIM then
        print( string.format( "[BanditAI] %s (%s): ACT %s ausente, usando fallback %s (hold=%s)", self:GetClass(), self:GetModel(), tostring(act), tostring(fb), hold ) )
      end
      return fb
    end
  end

  -- Ultimo recurso ABSOLUTO: nada do que a gente mapeou explicitamente
  -- resolveu (nem HL2MP nem classico). Em vez de desistir e deixar
  -- T-posar, tenta pelo menos o idle armado do hold -- cobre qualquer
  -- ACT que a gente nao previu (ex: variantes de "aim" durante
  -- schedules de cobertura/recuo, como ACT_WALK_AIM).
  local lastResort = HL2MP_IDLE_BY_HOLD[ hold ]
  if lastResort and self:SelectWeightedSequence( lastResort ) != -1 then
    if BANDIT_DEBUG_ANIM then
      print( string.format( "[BanditAI] %s (%s): ACT %s sem NENHUM mapeamento, usando idle do hold (Activity) como ultimo recurso", self:GetClass(), self:GetModel(), tostring(act) ) )
    end
    return lastResort
  end

  -- Se nem por Activity achou o idle, tenta pelo NOME exato da
  -- sequencia (ex: "idle_pistol") -- alguns modelos tem a sequencia
  -- sem Activity associada no .qc.
  local idleSeqByName = self:ResolveHoldSequence( "idle_" )
  if idleSeqByName > 0 then
    if BANDIT_DEBUG_ANIM then
      print( string.format( "[BanditAI] %s (%s): ACT %s sem mapeamento nem por Activity, usando idle_%s por NOME", self:GetClass(), self:GetModel(), tostring(act), hold ) )
    end
    self:ResetSequence( idleSeqByName )
    return act -- devolve o act original (engine so usa isso pra tentar de novo depois; ja aplicamos a sequencia na mao)
  end

  -- Nenhum fallback funcionou: loga pra voce saber exatamente o que falta no .mdl.
  if BANDIT_DEBUG_ANIM then
    print( string.format( "[BanditAI] AVISO: %s (%s) NAO tem nenhuma sequencia para ACT %s nem fallback -> vai T-posar", self:GetClass(), self:GetModel(), tostring(act) ) )
  end

  return act
end

-- ============================================================
-- MELHORIAS DE IA: cobertura, recuo, anomalias, municao infinita
-- ============================================================

-- Parametros ajustaveis (pode mudar aqui se quiser recalibrar)
ENT.CoverSearchRadius   = 700   -- raio de busca por prop pra se cobrir
ENT.RetreatCheckRadius  = 350   -- raio pra contar quantos inimigos tem perto
ENT.RetreatEnemyCount   = 3     -- a partir de quantos inimigos perto ele recua
ENT.AnomalyDangerRadius = 140   -- distancia minima de qualquer anom_*
ENT.VirtualClipMax      = 40    -- "balas" antes de forcar uma recarga (infinita, nunca acaba de vez)
ENT.ReloadDuration       = 2.3  -- duracao da recarga (segundos) -- unico momento em que para de atirar alem de se mover

-- ------------------------------------------------------------
-- Municao "infinita": a arma em si ja nao gasta municao real pra
-- NPCs (a maioria das armas do addon so desconta do clip quando o
-- dono NAO e NPC). A gente so simula um clip por cima, do nosso
-- lado, pra forcar uma pausa de recarga de vez em quando (fica mais
-- natural) sem nunca deixar a municao acabar de verdade.
-- ------------------------------------------------------------
function ENT:IsVirtualReloading()
  return self._virtualReloading == true
end

function ENT:BeginVirtualReload()
  if self:IsVirtualReloading() then return end

  self._virtualReloading = true
  self:ForceReloadPose()

  local ent = self
  timer.Simple( self.ReloadDuration, function()
    if not IsValid( ent ) then return end
    ent._virtualClip = ent.VirtualClipMax
    ent._virtualReloading = false
  end )
end

-- Chamado a cada tiro (via ForceAttackPose, disparada pela propria
-- arma). Decrementa o clip virtual e forca recarga quando zera --
-- nunca fica sem bala de verdade, so pausa periodicamente.
function ENT:TickVirtualAmmo()
  self._virtualClip = ( self._virtualClip or self.VirtualClipMax ) - 1
  if self._virtualClip <= 0 then
    self:BeginVirtualReload()
  end
end

-- ------------------------------------------------------------
-- Cobertura: acha um prop solido perto que bloqueie a linha de
-- visao do inimigo, e devolve um ponto atras dele pra se esconder.
-- Nao depende de node graph/AI nodes do mapa (que a maioria dos
-- mapas de GMod nao tem).
-- ------------------------------------------------------------
local COVER_PROP_CLASSES = {
  prop_physics = true,
  prop_dynamic = true,
  prop_static  = true, -- prop_static nao aparece em ents.FindInSphere (sem entidade), mas nao custa nada deixar aqui
}

function ENT:FindCoverPoint( enemy )
  if not IsValid( enemy ) then return nil end

  local enemyPos = enemy:WorldSpaceCenter()
  local myPos = self:GetPos()
  local best, bestDist

  for _, ent in ipairs( ents.FindInSphere( myPos, self.CoverSearchRadius ) ) do
    if IsValid( ent ) and ent != self and COVER_PROP_CLASSES[ ent:GetClass() ] then
      local solid = ent:GetSolid()
      if solid and solid != SOLID_NONE and not ent:IsPlayerHolding() then
        local propPos = ent:GetPos()

        -- ponto do lado OPOSTO ao inimigo, encostado no prop
        local awayDir = propPos - enemyPos
        awayDir.z = 0
        if awayDir:LengthSqr() > 1 then
          awayDir:Normalize()
          local coverPoint = propPos + awayDir * 70

          -- confirma que o prop realmente tampa a visao do inimigo pra esse ponto
          local tr = util.TraceLine( {
            start   = enemyPos,
            endpos  = coverPoint + Vector( 0, 0, 40 ),
            filter  = { self, ent },
            mask    = MASK_SOLID,
          } )

          if tr.Entity == ent or tr.Fraction < 0.97 then
            local dist = myPos:Distance( coverPoint )
            if not bestDist or dist < bestDist then
              best = coverPoint
              bestDist = dist
            end
          end
        end
      end
    end
  end

  return best
end

-- ------------------------------------------------------------
-- Recuo: conta quantos inimigos (hostis de verdade, D_HT) estao
-- perto. Se for gente demais, e melhor recuar em vez de brigar.
-- ------------------------------------------------------------
function ENT:CountNearbyHostiles( radius )
  local count = 0
  for _, ent in ipairs( ents.FindInSphere( self:GetPos(), radius ) ) do
    if IsValid( ent ) and ent != self and ( ent:IsPlayer() or ent:IsNPC() ) and ent:Alive() then
      if self:Disposition( ent ) == D_HT then
        count = count + 1
      end
    end
  end
  return count
end

function ENT:FindRetreatPoint( enemy )
  local myPos = self:GetPos()
  local awayDir = myPos - ( IsValid( enemy ) and enemy:GetPos() or myPos + Vector( 1, 0, 0 ) )
  awayDir.z = 0
  if awayDir:LengthSqr() < 1 then
    awayDir = Vector( math.random( -1, 1 ), math.random( -1, 1 ), 0 )
  end
  awayDir:Normalize()

  return myPos + awayDir * 320
end

-- ------------------------------------------------------------
-- Anomalias: todas as entidades de anomalia desse addon comecam
-- com "anom_" (anom_electra_anomaly, anom_kisel_anomaly, etc).
-- ------------------------------------------------------------
function ENT:GetNearbyAnomaly( radius )
  local myPos = self:GetPos()
  for _, ent in ipairs( ents.FindByClass( "anom_*" ) ) do
    if IsValid( ent ) and myPos:DistToSqr( ent:GetPos() ) <= radius * radius then
      return ent
    end
  end
  return nil
end
