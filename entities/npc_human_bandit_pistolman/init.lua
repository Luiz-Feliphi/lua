AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include('shared.lua')

-- Preset
ENT.bleeds      = true
ENT.StartHealth = 100
ENT.PlayerFriendly = false
ENT.flatbulletresistance = 25
ENT.percentbulletresistance = 20
ENT.lootChance = 33
ENT.lootGroup = "bandit_pistol_loot"
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
  {{"nagantrev", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 3 }}, "weapon_npc_brhp"},
  {{"m1917", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 3 }}, "weapon_npc_brhp"},
  {{"tokarev", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 5 }}, "weapon_npc_tokarev"},
  {{"brhp", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 5 }}, "weapon_npc_brhp"},
  {{"rugermk3", { ["durability"] = 10, ["wear"] = 15, ["ammo"] = 5 }}, "weapon_npc_rugermk3"},
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
ENT.IsSTALKERNPC = true
ENT.HoldType = "pistol"  -- estilo de animacao ACT_HL2MP_* (idle/walk/run/attack) para esta classe de arma
   
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

  -- Forca a pose de idle certa logo no spawn, pra nao ficar nem
  -- um instante na sequencia 0 ("ragdoll", que E um T-pose
  -- visualmente nesse modelo) antes do primeiro Think(). Prioriza
  -- o nome exato da sequencia, que sabemos que existe de verdade.
  local idleByName = self:ResolveHoldSequence( "idle_" )
  if idleByName > 0 then
    self:ResetSequence( idleByName )
  else
    local idleAct = self:TranslateActivity( ACT_IDLE )
    local idleSeq = self:SelectWeightedSequence( idleAct )
    if idleSeq != -1 and idleSeq != 0 then
      self:ResetSequence( idleSeq )
    end
  end
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
    self:AddEntityRelationship( dmg:GetAttacker(), D_HT, 10 )
    self:SetEnemy(dmg:GetAttacker())

    -- FIX: antes so registrava o inimigo e esperava o proximo
    -- SelectSchedule natural pra virar e encarar -- isso podia
    -- demorar e parecer "burro" (levava tiro e continuava olhando
    -- pra outro lugar). Agora forca a reacao de encarar na hora.
    if IsValid( dmg:GetAttacker() ) then
      self:SetSchedule( SCHED_COMBAT_FACE )
    end
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
-- FACÇÕES: bandit é hostil a merc e militar, aliado de outros
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

    if BANDIT_DEBUG_ANIM and (self._aiHeartbeat or 0) < CurTime() then
      self._aiHeartbeat = CurTime() + 4
      print( string.format( "[BanditAI-Think] %s pos=%s enemy=%s anomalyCheck=%s", self:GetClass(), tostring(self:GetPos()), tostring(IsValid(self:GetEnemy()) and self:GetEnemy():GetClass() or "nenhum"), tostring(self.GetNearbyAnomaly ~= nil) ) )
    end

    -- PRIORIDADE ABSOLUTA (roda todo tick, interrompe QUALQUER
    -- schedule em andamento -- inclusive um SCHED_CHASE_ENEMY
    -- longo, que so voltaria a chamar nosso SelectSchedule
    -- quando terminasse sozinho, tarde demais pra evitar
    -- atravessar uma anomalia ou ficar cercado).
    local nearbyAnomaly = self.GetNearbyAnomaly and self:GetNearbyAnomaly( self.AnomalyDangerRadius )
    if IsValid( nearbyAnomaly ) then
      if not self._fleeingAnomaly then
        self._fleeingAnomaly = true
        if BANDIT_DEBUG_ANIM then print( string.format( "[BanditAI-Think] %s FUGINDO de anomalia perto", self:GetClass() ) ) end
        local away = self:GetPos() - nearbyAnomaly:GetPos()
        away.z = 0
        if away:LengthSqr() < 1 then away = Vector( 1, 0, 0 ) end
        away:Normalize()
        self:SetLastPosition( self:GetPos() + away * 220 )
        self:SetSchedule( SCHED_FORCED_GO_RUN )
      end
      return
    else
      self._fleeingAnomaly = false
    end

    if IsValid( self:GetEnemy() ) and self.CountNearbyHostiles and (self._nextSwarmCheck or 0) < CurTime() then
      self._nextSwarmCheck = CurTime() + 1
      if self:CountNearbyHostiles( self.RetreatCheckRadius ) >= self.RetreatEnemyCount then
        if BANDIT_DEBUG_ANIM then print( string.format( "[BanditAI-Think] %s recuando: cercado por %d inimigos", self:GetClass(), self:CountNearbyHostiles( self.RetreatCheckRadius ) ) ) end
        self:SetLastPosition( self:FindRetreatPoint( self:GetEnemy() ) )
        self:SetSchedule( SCHED_FORCED_GO_RUN )
        return
      end
    end

        -- De vez em quando (a cada 3-6s), se estiver bem perto do
    -- inimigo, quebra o combate estatico pra tentar cobertura em
    -- vez de so trocar tiro parado no lugar. So faccoes que
    -- procuram cobertura (self.SeeksCover) fazem isso.
    if self.SeeksCover and IsValid( self:GetEnemy() ) and self.FindCoverPoint and (self._nextReposition or 0) < CurTime() then
      self._nextReposition = CurTime() + math.random( 2, 4 )
      if math.random() < 0.55 and self:GetPos():DistToSqr( self:GetEnemy():GetPos() ) < ( 750 * 750 ) then
        local coverPoint = self:FindCoverPoint( self:GetEnemy() )
        if coverPoint then
          if BANDIT_DEBUG_ANIM then print( string.format( "[BanditAI-Think] %s indo pra cobertura (reposicionamento)", self:GetClass() ) ) end
          self:SetLastPosition( coverPoint )
          self:SetSchedule( SCHED_FORCED_GO_RUN )
          return
        end
      end
    end

if (self.RecheckEnemyTimer or 0) < CurTime() then
      self.RecheckEnemyTimer = CurTime() + 8
      self:InitEnemies()
    end

    self:FixAnimationDesync()
    self:MaintainAttackPose()
  end
end

function ENT:FixAnimationDesync()
  -- IMPORTANTE: nesses modelos (flaymi/Anomaly) a sequencia
  -- INDICE 0 se chama literalmente "ragdoll" -- e uma pose de
  -- referencia pra fisica, NAO um idle, e visualmente E um
  -- T-pose. Se o NPC cair pra sequencia 0 OU -1 por QUALQUER
  -- motivo (inclusive falha interna do engine antes de chegar
  -- no nosso TranslateActivity), a gente forca pelo NOME exato
  -- (idle_<hold>) que sabemos que existe de verdade no modelo.
  local seq = self:GetSequence()
  if seq == -1 or seq == 0 then
    local idleByName = self:ResolveHoldSequence( "idle_" )
    if idleByName > 0 then
      self:ResetSequence( idleByName )
    else
      local idleAct = self:TranslateActivity( ACT_IDLE )
      local idleSeq = self:SelectWeightedSequence( idleAct )
      if idleSeq != -1 and idleSeq != 0 then
        self:ResetSequence( idleSeq )
      end
    end
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

    -- ============================================================
    -- PRIORIDADE MAXIMA: anomalia por perto. Ignora tudo (combate
    -- incluso) e sai andando pra longe primeiro.
    -- ============================================================
    local nearbyAnomaly = self:GetNearbyAnomaly( self.AnomalyDangerRadius )
    if IsValid( nearbyAnomaly ) then
      local away = self:GetPos() - nearbyAnomaly:GetPos()
      away.z = 0
      if away:LengthSqr() < 1 then away = Vector( 1, 0, 0 ) end
      away:Normalize()
      self:SetLastPosition( self:GetPos() + away * 220 )
      self:SetSchedule( SCHED_FORCED_GO_RUN )
      return
    end

    local haslos = self:HasLOS()

    local distance = 0
    local enemy_pos = 0
    if self:GetEnemy() == nil then
      self:FindEnemyDan()
      -- If there's still no enemy after looking for one, we patrol
      if( self:GetEnemy() == nil) then
        self:SetSchedule(SCHED_PATROL_WALK)
        self.TakingCover = false
        return
      end
    else

      if self.WantsCoverAfterBurst then
        self.WantsCoverAfterBurst = false
        -- Nao forcamos mais SCHED_TAKE_COVER_FROM_ENEMY aqui (isso
        -- costumava travar em T-pose se o mapa nao tivesse node
        -- graph pra cobertura). Deixamos a logica normal abaixo
        -- (distancia/LOS) decidir a proxima acao, que so usa
        -- schedules/animacoes que a gente ja sabe que funcionam.
      end

      -- ============================================================
      -- Gente demais por perto: melhor recuar do que brigar.
      -- ============================================================
      if self:CountNearbyHostiles( self.RetreatCheckRadius ) >= self.RetreatEnemyCount then
        self:SetLastPosition( self:FindRetreatPoint( self:GetEnemy() ) )
        self:SetSchedule( SCHED_FORCED_GO_RUN )
        return
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
      if distance > 750 then
        self:SetSchedule(SCHED_CHASE_ENEMY)
      elseif (distance < 750 && distance > 200) then
        if (!haslos) then
          self:SetSchedule(SCHED_ESTABLISH_LINE_OF_FIRE) --move to shoot enemy
        else
          if (self.NextAttack < CurTime() and self:HasLOS() and not self:IsVirtualReloading()) then
            self:ForceAttackPose()
            self:StartSchedule(schedd)
          else
            -- Recarregando ou esperando o proximo tiro: procura um
            -- prop solido por perto pra se cobrir em vez de ficar
            -- parado a mostra.
            local coverPoint = self:FindCoverPoint( self:GetEnemy() )
            if coverPoint then
              self:SetLastPosition( coverPoint )
              self:SetSchedule( SCHED_FORCED_GO_RUN )
            else
              self:SetSchedule( SCHED_BACK_AWAY_FROM_ENEMY )
            end
          end
        end
      elseif ( haslos and distance < 200 and (self.NextAttack or 0) < CurTime() and not self:IsVirtualReloading()) then
        self:ForceAttackPose()
        self:StartSchedule(schedd)
        self.NextAttack = CurTime() + 0.15 -- so o suficiente pra nao re-triggar a mesma schedule no mesmo tick; o ritmo de tiro de verdade e o da arma
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
end

function ENT:HasLOS()
  if IsValid(self:GetEnemy()) then
    local tracedata = {}

    tracedata.start = self:GetShootPos()
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