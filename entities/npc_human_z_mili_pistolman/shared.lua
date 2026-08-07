ENT.Base = "base_ai"
ENT.SeeksCover = false
ENT.Type = "ai"
  
ENT.PrintName = "Zombified STALKER"
ENT.Author = "gumlefar & verne"
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
  if self.ForceReloadPose then self:ForceReloadPose() end -- so existe nos bandits (sistema de gesture); outras faccoes usam a anim classica normal

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
