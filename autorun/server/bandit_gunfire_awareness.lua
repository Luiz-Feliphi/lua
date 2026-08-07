-- ============================================================
-- CONSCIENCIA DE TIRO (suppression): faz os NPCs perceberem que
-- estao sendo alvejados mesmo quando o tiro ERRA, igual no
-- S.T.A.L.K.E.R. Clear Sky -- eles nao esperam levar dano pra saber
-- que tem gente atirando neles.
--
-- Usa o hook nativo EntityFireBullets (dispara ANTES do trace da
-- bala acontecer, pra QUALQUER entidade que atire: jogador ou NPC).
-- Calcula se a linha de tiro passa perto de algum NPC hostil ao
-- atirador e, se sim, alerta ele na hora (define o atirador como
-- inimigo e forca virar/encarar), sem precisar acertar de verdade.
-- ============================================================

if not SERVER then return end

local SUPPRESSION_RADIUS = 90   -- distancia maxima da linha de tiro pra "sentir" a bala passando perto
local SUPPRESSION_RANGE  = 3000 -- alcance maximo considerado

local function IsOurNPC( ent )
  return IsValid( ent ) and ent.IsSTALKERNPC == true
end

-- util.ClosestPointOnLine nao existe no GMod -- calcula na mao a
-- projecao do ponto p sobre o segmento a-b, limitada ao segmento.
local function ClosestPointOnSegment( a, b, p )
  local ab = b - a
  local abLenSqr = ab:Dot( ab )
  if abLenSqr < 0.0001 then return a end

  local t = ( p - a ):Dot( ab ) / abLenSqr
  t = math.Clamp( t, 0, 1 )
  return a + ab * t
end

hook.Add( "EntityFireBullets", "BanditSuppressionAwareness", function( ent, data )
  if not IsValid( ent ) then return true end

  local src = data.Src or ent:GetShootPos()
  local dir = data.Dir
  if not dir or dir:LengthSqr() < 0.01 then return true end
  dir = dir:GetNormalized()

  local endPos = src + dir * SUPPRESSION_RANGE

  for _, npc in ipairs( ents.FindInSphere( src, SUPPRESSION_RANGE ) ) do
    if IsOurNPC( npc ) and npc != ent and npc:Alive() then
      if npc:Disposition( ent ) == D_HT then
        local closest = ClosestPointOnSegment( src, endPos, npc:GetPos() )
        local distToLine = npc:GetPos():Distance( closest )

        if distToLine <= SUPPRESSION_RADIUS then
          if not IsValid( npc:GetEnemy() ) then
            npc:SetEnemy( ent )
          end
          if npc.WasInCombat != nil then
            npc.WasInCombat = true
          end
          npc:SetSchedule( SCHED_COMBAT_FACE )

          if BANDIT_DEBUG_ANIM then
            print( string.format( "[BanditAI] %s sentiu tiro de %s passando perto (dist=%.0f) mesmo sem acertar", npc:GetClass(), tostring(ent), distToLine ) )
          end
        end
      end
    end
  end

  return true
end )

print( "[BanditAI] Consciencia de tiro (suppression) carregada." )
