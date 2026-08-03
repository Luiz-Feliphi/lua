-- ============================================================
-- INTERCEPTACAO GLOBAL DE ANIMACAO DE ARMA PROS BANDITS STALKER
-- ============================================================
-- Qualquer weapon_npc_* (Tokarev, AK74, obrez, etc.) chama
-- Weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK / ACT_VM_RELOAD / ...)
-- quando atira ou recarrega. Os modelos STALKER (flaymi/Anomaly)
-- nao tem essas sequencias ACT_VM_* compiladas, entao isso trava o
-- NPC em T-pose.
--
-- Em vez de editar cada arma uma por uma, a gente intercepta
-- SendWeaponAnim aqui, globalmente: se o dono da arma for um dos
-- nossos NPCs bandit (ENT.IsSTALKERNPC), redireciona pra
-- ForceAttackPose()/ForceReloadPose() (definidas no shared.lua de
-- cada bandit), que resolvem a animacao certa (ACT_HL2MP_*) via
-- TranslateActivity. Pra qualquer outra arma/dono (players, outros
-- NPCs), o comportamento original continua 100% intacto.
-- ============================================================

if not SERVER then return end

local WEAPON_META = FindMetaTable( "Weapon" )
if not WEAPON_META then return end

local RealSendWeaponAnim = WEAPON_META.SendWeaponAnim
if not RealSendWeaponAnim then return end

function WEAPON_META:SendWeaponAnim( act )
  local owner = self:GetOwner()

  if BANDIT_DEBUG_ANIM then
    print( string.format( "[BanditAI] SendWeaponAnim interceptado: arma=%s dono=%s act=%s IsSTALKERNPC=%s", self:GetClass(), IsValid(owner) and owner:GetClass() or "invalido", tostring(act), tostring(IsValid(owner) and owner.IsSTALKERNPC) ) )
  end

  if IsValid( owner ) and owner.IsSTALKERNPC then
    if act == ACT_VM_RELOAD then
      if owner.ForceReloadPose then
        owner:ForceReloadPose()
        return
      end
    elseif owner.ForceAttackPose then
      owner:ForceAttackPose()
      return
    end
  end

  return RealSendWeaponAnim( self, act )
end

--print( "[BanditAI] Interceptacao global de SendWeaponAnim carregada." )
