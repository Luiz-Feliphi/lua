AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include('shared.lua')

-- Preset
ENT.bleeds      = true
ENT.StartHealth = 100
ENT.PlayerFriendly = false
ENT.flatbulletresistance = 10
ENT.percentbulletresistance = 20
ENT.lootChance = 33
ENT.lootGroup = "bandit_rifle_loot"
ENT.selectedWeaponItem = nil 
ENT.selectedWeaponSWEP = nil

ENT.alertsounds  = {
  "npc/bandit/enemy_1.ogg",
  "npc/bandit/enemy_2.ogg",
  "npc/bandit/enemy_3.ogg",
  "npc/bandit/enemy_4.ogg",
  "npc/bandit/enemy_5.ogg",
  "npc/bandit/enemy_6.ogg",
  "npc/bandit/enemy_7.ogg",
}

ENT.attacksounds = {  
  "npc/bandit/attack_1.ogg", 
  "npc/bandit/attack_2.ogg",
  "npc/bandit/attack_3.ogg",
  "npc/bandit/attack_4.ogg",
  "npc/bandit/attack_5.ogg",
  "npc/bandit/attack_6.ogg"
}

ENT.hurtsounds   = {
  "npc/bandit/hit_1.ogg",
  "npc/bandit/hit_2.ogg",
  "npc/bandit/hit_3.ogg",
  "npc/bandit/hit_4.ogg",
  "npc/bandit/hit_5.ogg",
  "npc/bandit/hit_6.ogg",
  "npc/bandit/hit_7.ogg"
}

ENT.diesounds    = {
  "npc/bandit/death_1.ogg",
  "npc/bandit/death_2.ogg",
  "npc/bandit/death_3.ogg",
  "npc/bandit/death_4.ogg",
  "npc/bandit/death_5.ogg",
  "npc/bandit/death_6.ogg"
}

ENT.models       = {
  "models/flaymi/anomaly/stalker_bandit/bandit1a_mask.mdl",
  "models/flaymi/anomaly/stalker_bandit/stalker_bandit3a.mdl",
  "models/flaymi/anomaly/stalker_bandit/stalker_bandit4a.mdl",
  "models/flaymi/anomaly/stalker_bandit/stalker_bandit_1.mdl",
  "models/flaymi/anomaly/stalker_bandit/stalker_bandit_1_mask.mdl",
  "models/flaymi/anomaly/stalker_bandit/stalker_bandit_3_mask.mdl",
  "models/flaymi/anomaly/stalker_bandit/stalker_bandit_4.mdl",
  "models/flaymi/anomaly/stalker_bandit/stalker_bandit_tr.mdl",
}

ENT.weapons      = {
  {{"ppsh", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 7 }}, "weapon_npc_ppsh"},
  {{"skorpion", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 5 }}, "weapon_npc_skorpion"},
  {{"saigasemi545", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 3 }}, "weapon_npc_rugermini14"},
  {{"ruger1022", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 5 }}, "weapon_npc_rugermini14"},
}

-- Live vars
ENT.Alerted     = false
ENT.MeleeAttacking = false
ENT.TakingCover = false
ENT.FindingLOS  = false
ENT.CanSeeEnemy = false
ENT.TimeToTakeCover = 0
ENT.GotACloseOne = false
ENT.dead = false
ENT.speaktime = 0
ENT.FireBurst = 0
ENT.NextAttack = 0
ENT.WasInCombat = false
ENT.SquadCombatCooldown = 0
ENT.IsSTALKERNPC = true
ENT.IsSquadAnchorClass = false  -- so shotgunners podem ser lideres/pontos de encontro do esquadrao
ENT.HoldType = "ar2"  -- estilo de animacao ACT_HL2MP_* (idle/walk/run/attack) para esta classe de arma
   
function ENT:Initialize()

  local selectedWeaponIndex = math.random(#self.weapons)
  for i=1, #self.weapons do
    if selectedWeaponIndex == i then
      self.selectedWeaponItem = self.weapons[i][1]
      self.selectedWeaponSWEP = self.weapons[i][2]
    end
  end

  self:Give(self.selectedWeaponSWEP)

  self:SetModel(self.models[math.random(1,#self.models)])

  self:SetSkin(math.random(1,self:SkinCount()))
  self:SetCollisionGroup(COLLISION_GROUP_NPC)
  self:SetCustomCollisionCheck( true )
   
  self:SetHullType( HULL_HUMAN )
  self:SetHullSizeNormal();
  self:SetSolid( SOLID_BBOX )
  self:SetMoveType( MOVETYPE_STEP )
  self:CapabilitiesAdd( CAP_MOVE_GROUND )
  self:CapabilitiesAdd( CAP_OPEN_DOORS )
  self:CapabilitiesAdd( CAP_SQUAD )
  self:CapabilitiesAdd( CAP_ANIMATEDFACE )
  self:CapabilitiesAdd( CAP_USE_WEAPONS )
  self:CapabilitiesAdd( CAP_SQUAD )
  self:CapabilitiesAdd( CAP_DUCK )
  self:CapabilitiesAdd( CAP_MOVE_SHOOT )
  self:CapabilitiesAdd( CAP_TURN_HEAD )
  self:CapabilitiesAdd( CAP_USE_SHOT_REGULATOR )
  self:CapabilitiesAdd( CAP_AIM_GUN )
  self:CapabilitiesAdd( CAP_WEAPON_RANGE_ATTACK1 )
  self:SetMaxYawSpeed( 5000 )

  self:SetHealth(self.StartHealth)
  self:SetEnemy(NULL)

  self:SetLagCompensated(true)

  self:AddRelationship("player D_HT 10")
  self:InitEnemies()

  self:SetCurrentWeaponProficiency(WEAPON_PROFICIENCY_VERY_GOOD )
end
   
function ENT:OnTakeDamage(dmg)
  if(dmg:IsDamageType(DMG_BULLET)) then
		dmg:SubtractDamage(self.flatbulletresistance)
		dmg:SetDamage(dmg:GetDamage()*(1 - (self.percentbulletresistance/100)))
		dmg:SetDamage(math.max(3,dmg:GetDamage())) --So he can't heal from our attacks
	end
  
  self:SpawnBlood(dmg)
  self:SetHealth(self:Health() - dmg:GetDamage())
  
  if math.random(2) == 1 then
    self:StopSpeechSounds()
    self:PlayRandomSound(self.hurtsounds)
  end

  if (dmg:GetAttacker():GetClass() != self:GetClass() && dmg:IsDamageType(DMG_BULLET)) then
    self:AddEntityRelationship( dmg:GetAttacker(), 1, 10 )
    self:SetEnemy(dmg:GetAttacker())
  end

  self.Alerted = true
  if self:Health() <= 0 && self.dead == false then
    self.dead = true;
    self:KilledDan()
    gamemode.Call( "OnNPCKilled",  self, dmg:GetAttacker(), dmg:GetInflictor() )
  end
end

local schedd = ai_schedule.New( "FireSched" )
schedd:EngTask( "TASK_FACE_ENEMY",       0 )
schedd:EngTask( "TASK_RANGE_ATTACK1",    0 )


-- ============================================================
-- FACÇÕES: merc é hostil a bandit e militar, aliado de outros
-- Ajuste as duas listas abaixo se quiser outra matriz de facção.
-- ============================================================
ENT.HostileClasses = {
  "npc_human_merc_*",
  "npc_human_mili_*",
  "npc_human_z_*",
  "npc_mutant_*",
}

ENT.FriendlyClasses = {
  "npc_human_bandit_*",
}

function ENT:InitEnemies()
  -- Hostil: bandit (e militar, se aplicável)
  for _, class in ipairs(self.HostileClasses) do
    local found = ents.FindByClass(class)
    for _, x in pairs(found) do
      x:AddEntityRelationship( self, D_HT, 10 )
      self:AddEntityRelationship( x, D_HT, 10 )
    end
  end

  -- Aliado: outros mercs
  for _, class in ipairs(self.FriendlyClasses) do
    local found = ents.FindByClass(class)
    for _, x in pairs(found) do
      x:AddEntityRelationship( self, D_LI, 10 )
      self:AddEntityRelationship( x, D_LI, 10 )
    end
  end
end

function ENT:Think()
  if self:Health() > 0 then

    if (self.RecheckEnemyTimer or 0) < CurTime() then
      self.RecheckEnemyTimer = CurTime() + 8
      self:InitEnemies()
    end

    self:FixAnimationDesync()
    self:MaintainAttackPose()
  end
end

-- ============================================================
-- FIX: pes deslizando no chao (animacao congelada num frame so
-- enquanto o corpo continua se movendo pelo mundo).
-- Isso acontece quando o playback rate da sequencia atual cai pra 0
-- (ou a sequencia fica invalida) e o motor para de avancar os frames
-- da animacao, mas o AI continua movendo o NPC normalmente.
-- ============================================================
function ENT:FixAnimationDesync()
  if self:GetSequence() == -1 then
    self:ResetSequence( self:SelectWeightedSequence( ACT_IDLE ) )
  end

  if self:GetPlaybackRate() == 0 then
    self:SetPlaybackRate( 1 )
  end
end

function ENT:PlayRandomSound(soundtable)
  if( (self.NextSound or 0) < CurTime() ) then
    local randsound = soundtable[math.random(1,#soundtable)]
    self:EmitSound( randsound, 100, 100)
    self.NextSound = CurTime() + SoundDuration(randsound) + 2.5
  end
end

function ENT:SelectSchedule()
  if self:Alive() then
    local haslos = self:HasLOS()

    local distance = 0
    local enemy_pos = 0
    if self:GetEnemy() == nil then
      self:FindEnemyDan()
      -- If there's still no enemy after looking for one, we patrol
      if( self:GetEnemy() == nil) then
        self.TakingCover = false
        if self.WasInCombat then
          -- acabou de sair de combate: espera um pouco antes de
          -- voltar a formar grupo, pra nao colar de volta na hora
          self.WasInCombat = false
          self.SquadCombatCooldown = CurTime() + 5
        end
        if self:SquadThink() then
          return -- comportamento de esquadrao assumiu a schedule deste think
        end
        self:SetSchedule(SCHED_PATROL_WALK)
        return
      end
    else

      self.WasInCombat = true

      if self.WantsCoverAfterBurst then
        self.WantsCoverAfterBurst = false
        -- Nao forcamos mais SCHED_TAKE_COVER_FROM_ENEMY aqui (isso
        -- costumava travar em T-pose se o mapa nao tivesse node
        -- graph pra cobertura). Deixamos a logica normal abaixo
        -- (distancia/LOS) decidir a proxima acao, que so usa
        -- schedules/animacoes que a gente ja sabe que funcionam.
      end

      if self.speaktime < CurTime() then
        self.speaktime = CurTime() + 8
        if math.random(1,100) < 30 then
          self:StopSpeechSounds()
          self:PlayRandomSound(self.attacksounds)
        end
      end

      enemy_pos = self:GetEnemy():GetPos()
      distance = self:GetPos():Distance(enemy_pos)
      if distance > 2000 then
        self:SetSchedule(SCHED_CHASE_ENEMY)
      elseif (distance < 2000 && distance > 600) then
        if (!haslos) then
          self:SetSchedule(SCHED_ESTABLISH_LINE_OF_FIRE) --move to shoot enemy
        else
          if (self.NextAttack < CurTime() and self:HasLOS()) then
            self:ForceAttackPose()
            self:StartSchedule(schedd)
            return
          end
        end
      elseif ( haslos and distance < 600) then
        if self.TakingCover == false then
          self.TakingCover = true
          self:SetSchedule( SCHED_TAKE_COVER_FROM_ENEMY )
        end
      else
        self.TakingCover = false
        self:SetSchedule(SCHED_CHASE_ENEMY)//move to shoot enemy
      end
    end
  end
end

function ENT:FindEnemyDan()
  local MyNearbyTargets = ents.FindInCone(self:GetPos(),self:GetForward(),7000,45)

  for k,v in pairs(MyNearbyTargets) do
    if v:Disposition(self) == D_HT || v:IsPlayer() then

      self:StopSpeechSounds()
      self:ResetEnemy()
      self:AddEntityRelationship( v, D_HT, 10 )
      self:SetEnemy(v)
      local distance = self:GetPos():Distance(v:GetPos())
      local randomsound = math.random(1,5)

      if self.Alerted == false then
        self:EmitSound( self.alertsounds[math.random(#self.alertsounds)], 400, 100)
      end
      self.Alerted = true
    end
  end
end

function ENT:StopSpeechSounds()
  for i = 1, #self.alertsounds do
    self:StopSound(self.alertsounds[i])
  end

  for i = 1, #self.attacksounds do
    self:StopSound(self.attacksounds[i])
  end
end

function ENT:StopHurtSounds()
  for i = 1, #self.hurtsounds do
    self:StopSound(self.hurtsounds[i])
  end
end

function ENT:SpawnBlood(dmg)
  if (self.bleeds) then
    local bloodeffect = ents.Create( "info_particle_system" )
    bloodeffect:SetKeyValue( "effect_name", "blood_impact_red_01" )
    bloodeffect:SetPos( dmg:GetDamagePosition() ) 
    bloodeffect:Spawn()
    bloodeffect:Activate() 
    bloodeffect:Fire( "Start", "", 0 )
    bloodeffect:Fire( "Kill", "", 0.1 )
  end
end

function ENT:KilledDan()

  self:StopSpeechSounds()
  self:StopHurtSounds()
  self:PlayRandomSound(self.diesounds)

  //create ragdoll
  local ragdoll = ents.Create( "prop_ragdoll" )
  ragdoll:SetModel( self:GetModel() )
  ragdoll:SetPos( self:GetPos() )
  ragdoll:SetAngles( self:GetAngles() )
  ragdoll:Spawn()
  ragdoll:SetSkin( self:GetSkin() )
  ragdoll:SetColor( self:GetColor() )
  ragdoll:SetMaterial( self:GetMaterial() )
  ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)

  cleanup.ReplaceEntity(self,ragdoll)
  undo.ReplaceEntity(self,ragdoll)

  if self:IsOnFire() then ragdoll:Ignite( math.Rand( 8, 10 ), 0 ) end


    for i=1,128 do
    local bone = ragdoll:GetPhysicsObjectNum( i )
    if IsValid( bone ) then
      local bonepos, boneang = self:GetBonePosition( ragdoll:TranslatePhysBoneToBone( i ) )
      bone:SetPos( bonepos )
      bone:SetAngles( boneang )
    end
  end

  -- Helix specific drops
  if(ix)then
    local item = self.selectedWeaponItem
    ix.item.Spawn(item[1], self:GetShootPos() + Vector(0,0,32), function(item, ent) ent.bTemporary = true end, AngleRand(), item[2] or {} )
  end

  if math.random(1, 100) <= self.lootChance then
    ragdoll:SetNetVar("loot", self.lootGroup)
  end

  ragdoll:Fire("kill","",180)

  self:Remove()
end

function ENT:ResetEnemy()
  if( self:GetEnemy() ) then
    self:SetEnemy(nil)
  end
end

function ENT:OnRemove()
  timer.Remove("melee_attack_timer" .. self.Entity:EntIndex( ))
  timer.Remove("melee_done_timer" .. self.Entity:EntIndex( ))

  -- Esquadrao: se eu era seguidor, me tiro da lista do meu lider
  if IsValid(self.SquadLeader) and self.SquadLeader.SquadFollowers then
    for i, f in ipairs(self.SquadLeader.SquadFollowers) do
      if f == self then
        table.remove(self.SquadLeader.SquadFollowers, i)
        break
      end
    end
  end

  -- Esquadrao: se eu era lider, sorteio um seguidor aleatorio pra
  -- virar o novo lider, e o resto do grupo passa a seguir ele.
  if self.SquadFollowers and #self.SquadFollowers > 0 then
    for i = #self.SquadFollowers, 1, -1 do
      if not IsValid(self.SquadFollowers[i]) or not self.SquadFollowers[i]:Alive() then
        table.remove(self.SquadFollowers, i)
      end
    end

    if #self.SquadFollowers > 0 then
      local newLeader = self.SquadFollowers[ math.random( #self.SquadFollowers ) ]

      newLeader.SquadLeader = nil
      newLeader.SquadFollowers = {}

      for _, f in ipairs( self.SquadFollowers ) do
        if f != newLeader and IsValid(f) then
          f.SquadLeader = newLeader
          table.insert( newLeader.SquadFollowers, f )
        end
      end
    end
  end
end

function ENT:HasLOS()
  if IsValid(self:GetEnemy()) then
    local tracedata = {}

    tracedata.start = self:GetShootPos() + Vector(0,0,32)
    if IsValid(self:GetEnemy():GetShootPos()) then
      tracedata.endpos = self:GetEnemy():GetShootPos()
    else
      tracedata.endpos = self:GetEnemy():GetPos() + Vector(0, 0, 8)
    end
    tracedata.filter = self

    local trace = util.TraceLine(tracedata)
    if trace.HitWorld == false then
      return true
    else 
      return false
    end
  end
  return false
end

-- ============================================================
-- MELHORIA: comportamento de esquadrao (bandits andando em grupo)
-- ============================================================
-- Regras pedidas:
-- - Um bandit sem lider/grupo escolhe o bandit mais proximo dele.
-- - Ele anda ate esse bandit escolhido (candidato).
-- - Quando chega perto o suficiente, passa a fazer parte do grupo
--   dele de verdade (vira "seguidor").
-- - Um lider aceita no maximo 3 seguidores.
-- - Se o candidato escolhido ja for seguidor de alguem, entra
--   direto no grupo do lider dele (evita corrente seguidor->seguidor).
-- - So participa de squad quando NAO tem inimigo (fora de combate).
--
-- v2: cada seguidor mantem uma posicao de FORMACAO fixa (slot 1, 2
-- ou 3) atras do lider, em vez de todo mundo mirar o mesmo ponto
-- (o que fazia parecer um "bando" desorganizado). Alem disso, o
-- seguidor NUNCA volta a patrulhar sozinho enquanto tiver lider
-- vivo -- ou ele anda ate a posicao de formacao, ou fica parado
-- esperando o lider se afastar de novo. Usa as schedules nativas
-- SCHED_FORCED_GO / SCHED_FORCED_GO_RUN (feitas pra navegar ate
-- NPC:SetLastPosition), que sao mais confiaveis que schedules
-- customizadas feitas na mao.
-- ============================================================

ENT.SquadMaxFollowers   = 3
ENT.SquadSearchRadius   = 2000  -- raio de busca por um bandit pra seguir
ENT.SquadJoinRadius     = 900   -- distancia pra "chegar perto" e virar seguidor de fato
ENT.SquadFollowDistance = 220   -- acima disso do slot de formacao, CORRE ate ele
ENT.SquadIdleRadius     = 60    -- dentro disso do slot de formacao, fica parado
ENT.SquadLeader         = nil   -- entidade lider (se este NPC for seguidor)
ENT.SquadFollowers      = nil   -- lista de seguidores (se este NPC for lider)
ENT.SquadCandidate      = nil   -- bandit que estou indo encontrar (ainda nao entrei no grupo)
ENT.NextSquadSearch     = 0

-- Offsets de formacao (local ao lider: x = frente/tras, y = lado)
-- slot 1 = atras-centro, slot 2 = atras-esquerda, slot 3 = atras-direita
ENT.SquadFormationOffsets = {
  Vector( -90,   0, 0 ),
  Vector( -70, -70, 0 ),
  Vector( -70,  70, 0 ),
}

function ENT:IsSquadLeader()
  return self.SquadFollowers != nil and #self.SquadFollowers > 0
end

function ENT:CleanSquadFollowers()
  if not self.SquadFollowers then return end
  for i = #self.SquadFollowers, 1, -1 do
    local f = self.SquadFollowers[i]
    if not IsValid(f) or not f:Alive() or f.SquadLeader != self then
      table.remove( self.SquadFollowers, i )
    end
  end
end

-- So procura por bandits da classe shotgunner: eles sao sempre o
-- ponto de encontro/lider do grupo, nunca as outras classes.
function ENT:FindNearestShotgunner()
  local nearest, nearestDist = nil, self.SquadSearchRadius
  for _, ent in pairs( ents.FindByClass( "npc_human_bandit_shotgunner" ) ) do
    if IsValid(ent) and ent != self and ent:Alive() then
      local dist = self:GetPos():Distance( ent:GetPos() )
      if dist < nearestDist then
        nearest = ent
        nearestDist = dist
      end
    end
  end
  return nearest
end

-- Retorna o slot (1, 2 ou 3) que este NPC ocupa na lista do lider.
function ENT:GetSquadSlot()
  if not IsValid( self.SquadLeader ) or not self.SquadLeader.SquadFollowers then return 1 end
  for i, f in ipairs( self.SquadLeader.SquadFollowers ) do
    if f == self then return i end
  end
  return 1
end

-- Calcula a posicao no mundo que este seguidor deve ocupar, baseada
-- na posicao/direcao do lider e no slot de formacao deste seguidor.
function ENT:GetSquadFormationPos()
  local leader = self.SquadLeader
  if not IsValid( leader ) then return self:GetPos() end

  local slot = self:GetSquadSlot()
  local offset = self.SquadFormationOffsets[ slot ] or self.SquadFormationOffsets[1]

  local forward = leader:GetForward()
  local right   = leader:GetRight()

  return leader:GetPos() + ( forward * offset.x ) + ( right * offset.y )
end

-- Retorna true se o comportamento de esquadrao assumiu a schedule
-- deste think (o SelectSchedule normal deve ser pulado), ou false
-- se o bandit deve seguir a patrulha normal.
function ENT:SquadThink()

  -- Ja sigo um lider valido? Entao NUNCA patrulho sozinho: ou ando
  -- ate meu slot de formacao, ou fico parado esperando o lider.
  if IsValid( self.SquadLeader ) and self.SquadLeader:Alive() then
    local formationPos = self:GetSquadFormationPos()
    local dist = self:GetPos():Distance( formationPos )

    if dist <= self.SquadIdleRadius then
      self:SetSchedule( SCHED_IDLE_STAND )
    elseif dist > self.SquadFollowDistance then
      self:SetLastPosition( formationPos )
      self:SetSchedule( SCHED_FORCED_GO_RUN )
    else
      self:SetLastPosition( formationPos )
      self:SetSchedule( SCHED_FORCED_GO )
    end

    return true
  end

  self.SquadLeader = nil -- lider sumiu/morreu, libera

  -- Eu sou o lider (tenho seguidores)? Patrulho normalmente, os
  -- seguidores que se organizam atras de mim.
  if self:IsSquadLeader() then
    self:CleanSquadFollowers()
    return false
  end

  -- Classes-ancora (shotgunner) nunca procuram nem entram no grupo
  -- de outra ancora: cada uma fica independente, servindo de ponto
  -- de encontro pras outras classes (pistolman/rifleman/sniper).
  if self.IsSquadAnchorClass then
    return false
  end

  -- Acabei de sair de combate: espera o cooldown antes de voltar
  -- a procurar/seguir grupo, pra nao reagrupar instantaneamente.
  if (self.SquadCombatCooldown or 0) > CurTime() then
    return false
  end

  -- Estou a caminho de um candidato (shotgunner) ainda nao confirmado?
  if IsValid( self.SquadCandidate ) and self.SquadCandidate:Alive() then
    local dist = self:GetPos():Distance( self.SquadCandidate:GetPos() )

    if dist <= self.SquadJoinRadius then
      -- Cheguei perto: confirma entrada no grupo.
      local targetLeader = self.SquadCandidate

      if targetLeader != self then
        targetLeader.SquadFollowers = targetLeader.SquadFollowers or {}
        if targetLeader.CleanSquadFollowers then targetLeader:CleanSquadFollowers() end

        if #targetLeader.SquadFollowers < self.SquadMaxFollowers then
          table.insert( targetLeader.SquadFollowers, self )
          self.SquadLeader = targetLeader
        end
      end

      self.SquadCandidate = nil
      return false -- no proximo think ja segue o lider normalmente
    else
      -- ainda indo ao encontro do candidato
      self:SetLastPosition( self.SquadCandidate:GetPos() )
      self:SetSchedule( SCHED_FORCED_GO_RUN )
      return true
    end
  end

  -- Sem lider e sem candidato: procura o shotgunner mais proximo de
  -- tempos em tempos. Se nao achar nenhum, continua patrulhando sozinho.
  if self.NextSquadSearch < CurTime() then
    self.NextSquadSearch = CurTime() + 4

    local nearest = self:FindNearestShotgunner()
    if IsValid(nearest) then
      self.SquadCandidate = nearest
    end
  end

  return false
end
