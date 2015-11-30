AddCSLuaFile()

SWEP.HoldType			= "fist"

if CLIENT then
   SWEP.PrintName			= "Magno-Hands"
   SWEP.Slot				= 4
   SWEP.Icon = "vgui/ttt/icon_cbar"   
   SWEP.ViewModelFOV = 54
end

SWEP.UseHands			= true
SWEP.Base				= "weapon_tttbase"
SWEP.ViewModel			= "models/weapons/c_arms_cstrike.mdl"
SWEP.WorldModel			= ""
SWEP.Weight			= 5
SWEP.DrawCrosshair		= false
SWEP.ViewModelFlip		= false
SWEP.Primary.Damage = 20
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= true
SWEP.Primary.Delay = 0.5
SWEP.Primary.Ammo		= "none"
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= true
SWEP.Secondary.Ammo		= "none"
SWEP.Secondary.Delay = 0.1

SWEP.Kind = WEAPON_CARRY

SWEP.InLoadoutFor = {ROLE_INNOCENT, ROLE_TRAITOR, ROLE_DETECTIVE}

SWEP.NoSights = true
SWEP.IsSilent = true
SWEP.AutoSpawnable = false
SWEP.AllowDelete = false -- never removed for weapon reduction
SWEP.AllowDrop = false

local allow_rag  = CreateConVar("ttt_ragdoll_carrying", "1")
local prop_force = CreateConVar("ttt_prop_carrying_force", "60000")
local no_throw   = CreateConVar("ttt_no_prop_throwing", "0")
local pin_rag    = CreateConVar("ttt_ragdoll_pinning", "1")
local pin_rag_inno = CreateConVar("ttt_ragdoll_pinning_innocents", "0")
local allow_wep = CreateConVar("ttt_weapon_carrying", "0")
local wep_range = CreateConVar("ttt_weapon_carrying_range", "50")

CARRY_WEIGHT_LIMIT = 45

local PIN_RAG_RANGE = 90

local player = player
local IsValid = IsValid
local CurTime = CurTime

local sound_single = Sound("weapons/slam/throw.wav")
local sound_open = Sound("Flesh.ImpactHard")

function SWEP:PreDrawViewModel( vm, wep, ply )
	vm:SetMaterial( "engine/occlusionproxy" )
end

function SWEP:KeyPress(ply, key)
	if key == IN_JUMP then
		local owner = self.Owner
		owner:ViewPunch(4,4,0)
	end
end

if SERVER then
   CreateConVar("ttt_crowbar_unlocks", "1", FCVAR_ARCHIVE)
   CreateConVar("ttt_crowbar_pushforce", "395", FCVAR_NOTIFY)
end

local function OpenableEnt(ent)
   local cls = ent:GetClass()
   if ent:GetName() == "" then
      return OPEN_NO
   elseif cls == "prop_door_rotating" then
      return OPEN_ROT
   elseif cls == "func_door" or cls == "func_door_rotating" then
      return OPEN_DOOR
   elseif cls == "func_button" then
      return OPEN_BUT
   elseif cls == "func_movelinear" then
      return OPEN_NOTOGGLE
   else
      return OPEN_NO
   end
end


local function CrowbarCanUnlock(t)
   return not GAMEMODE.crowbar_unlocks or GAMEMODE.crowbar_unlocks[t]
end

function SWEP:OpenEnt(hitEnt)
   if SERVER and GetConVar("ttt_crowbar_unlocks"):GetBool() then
      local openable = OpenableEnt(hitEnt)

      if openable == OPEN_DOOR or openable == OPEN_ROT then
         local unlock = CrowbarCanUnlock(openable)
         if unlock then
            hitEnt:Fire("Unlock", nil, 0)
         end

         if unlock or hitEnt:HasSpawnFlags(256) then
            if openable == OPEN_ROT then
               hitEnt:Fire("OpenAwayFrom", self.Owner, 0)
            end
            hitEnt:Fire("Toggle", nil, 0)
         else
            return OPEN_NO
         end
      elseif openable == OPEN_BUT then
         if CrowbarCanUnlock(openable) then
            hitEnt:Fire("Unlock", nil, 0)
            hitEnt:Fire("Press", nil, 0)
         else
            return OPEN_NO
         end
      elseif openable == OPEN_NOTOGGLE then
         if CrowbarCanUnlock(openable) then
            hitEnt:Fire("Open", nil, 0)
         else
            return OPEN_NO
         end
      end
      return openable
   else
      return OPEN_NO
   end
end

function SWEP:PrimaryAttack()
   self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

   local anim = "fists_right"
   local vm = self.Owner:GetViewModel()
   local owner = self.Owner

   if not IsValid(self.Owner) then return end

   if self.Owner.LagCompensation then
      self.Owner:LagCompensation(true)
   end

   local spos = self.Owner:GetShootPos()
   local sdest = spos + (self.Owner:GetAimVector() * 70)

   local tr_main = util.TraceLine({start=spos, endpos=sdest, filter=self.Owner, mask=MASK_SHOT_HULL})
   local hitEnt = tr_main.Entity

   self.Weapon:EmitSound(sound_single)

   if IsValid(hitEnt) or tr_main.HitWorld then
      vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
      owner:ViewPunch( Angle( 4, 4, 0 ) )
      self.Owner:SetAnimation( PLAYER_ATTACK1 )
	  
	  self.Weapon:EmitSound(sound_open)

      if not (CLIENT and (not IsFirstTimePredicted())) then
         local edata = EffectData()
         edata:SetStart(spos)
         edata:SetOrigin(tr_main.HitPos)
         edata:SetNormal(tr_main.Normal)
         edata:SetSurfaceProp(tr_main.SurfaceProps)
         edata:SetHitBox(tr_main.HitBox)
         edata:SetEntity(hitEnt)

         if hitEnt:IsPlayer() or hitEnt:GetClass() == "prop_ragdoll" then
            util.Effect("BloodImpact", edata)
            self.Owner:LagCompensation(false)
            self.Owner:FireBullets({Num=1, Src=spos, Dir=self.Owner:GetAimVector(), Spread=Vector(0,0,0), Tracer=0, Force=1, Damage=0})
         else
            util.Effect("Stunstickimpact", edata)
         end
      end
   else
      vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
      owner:ViewPunch( Angle( 4, 4, 0 ) )
      self.Owner:SetAnimation( PLAYER_ATTACK1 )
   end


   if CLIENT then
   else -- SERVER
      local tr_all = nil
      tr_all = util.TraceLine({start=spos, endpos=sdest, filter=self.Owner})

      if hitEnt and hitEnt:IsValid() then
         if self:OpenEnt(hitEnt) == OPEN_NO and tr_all.Entity and tr_all.Entity:IsValid() then
            self:OpenEnt(tr_all.Entity)
         end

         local dmg = DamageInfo()
         dmg:SetDamage(self.Primary.Damage)
         dmg:SetAttacker(self.Owner)
         dmg:SetInflictor(self.Weapon)
         dmg:SetDamageForce(self.Owner:GetAimVector() * 1500)
         dmg:SetDamagePosition(self.Owner:GetPos())
         dmg:SetDamageType(DMG_CLUB)

         hitEnt:DispatchTraceAttack(dmg, spos + (self.Owner:GetAimVector() * 3), sdest)    
      else
         if tr_all.Entity and tr_all.Entity:IsValid() then
            self:OpenEnt(tr_all.Entity)
         end
      end
   end

   if self.Owner.LagCompensation then
      self.Owner:LagCompensation(false)
   end
end

function SWEP:SecondaryAttack()
   self:DoAttack(true)
end

function SWEP:GetClass()
   return "fists"
end

function SWEP:OnDrop()
   self:Reset()
   self:Remove()
end

function SWEP:Deploy()
   local vm = self.Owner:GetViewModel()
   vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_draw" ) )
   self:Reset()
   return true
end

function SWEP:Holster( wep )
   if ( IsValid( self.Owner ) && CLIENT && self.Owner:IsPlayer() ) then
      local vm = self.Owner:GetViewModel()
      if ( IsValid( vm ) ) then vm:SetMaterial( "" ) end
   end
   self:Reset()
   return true
end

function SWEP:OnRemove()
   self:Reset()
end

function SWEP:ShouldDropOnDie()
   return false
end


local function SetSubPhysMotionEnabled(ent, enable)
   if not IsValid(ent) then return end

   for i=0, ent:GetPhysicsObjectCount()-1 do
      local subphys = ent:GetPhysicsObjectNum(i)
      if IsValid(subphys) then
         subphys:EnableMotion(enable)
         if enable then
            subphys:Wake()
         end
      end
   end
end

local function KillVelocity(ent)
   ent:SetVelocity(vector_origin)
   SetSubPhysMotionEnabled(ent, false)
   timer.Simple(0, function() SetSubPhysMotionEnabled(ent, true) end)
end

function SWEP:Reset(keep_velocity)
   if IsValid(self.CarryHack) then
      self.CarryHack:Remove()
   end

   if IsValid(self.Constr) then
      self.Constr:Remove()
   end

   if IsValid(self.EntHolding) then
      if not self.EntHolding:IsWeapon() then
         if not IsValid(self.PrevOwner) then
            self.EntHolding:SetOwner(nil)
         else
            self.EntHolding:SetOwner(self.PrevOwner)
         end
      end

      local phys = self.EntHolding:GetPhysicsObject()
      if IsValid(phys) then
         phys:ClearGameFlag(FVPHYSICS_PLAYER_HELD)
         phys:AddGameFlag(FVPHYSICS_WAS_THROWN)
         phys:EnableCollisions(true)
         phys:EnableGravity(true)
         phys:EnableDrag(true)
         phys:EnableMotion(true)
      end

      if (not keep_velocity) and (no_throw:GetBool() or self.EntHolding:GetClass() == "prop_ragdoll") then
         KillVelocity(self.EntHolding)
      end
   end

   self.dt.carried_rag = nil

   self.EntHolding = nil
   self.CarryHack = nil
   self.Constr = nil
end
SWEP.reset = SWEP.Reset

function SWEP:CheckValidity()

   if (not IsValid(self.EntHolding)) or (not IsValid(self.CarryHack)) or (not IsValid(self.Constr)) then
      if (self.EntHolding or self.CarryHack or self.Constr) then
         self:Reset()
      end

      return false
   else
      return true
   end
end

local function PlayerStandsOn(ent)
   for _, ply in pairs(player.GetAll()) do
      if ply:GetGroundEntity() == ent and ply:IsTerror() then
         return true
      end
   end

   return false
end

if SERVER then

local ent_diff = vector_origin
local ent_diff_time = CurTime()

local stand_time = 0
function SWEP:Think()
   if not self:CheckValidity() then return end
   if CurTime() > ent_diff_time then
      ent_diff = self:GetPos() - self.EntHolding:GetPos()
      if ent_diff:Dot(ent_diff) > 40000 then
         self:Reset()
         return
      end

      ent_diff_time = CurTime() + 1
   end

   if CurTime() > stand_time then

      if PlayerStandsOn(self.EntHolding) then
         self:Reset()
         return
      end

      stand_time = CurTime() + 0.1
   end

   self.CarryHack:SetPos(self.Owner:EyePos() + self.Owner:GetAimVector() * 70)

   self.CarryHack:SetAngles(self.Owner:GetAngles())

   self.EntHolding:PhysWake()
end

end

function SWEP:MoveObject(phys, pdir, maxforce, is_ragdoll)
   if not IsValid(phys) then return end
   local speed = phys:GetVelocity():Length()
   local force = maxforce + (1 - maxforce) * (speed / 125)

   if is_ragdoll then
      force = force * 2
   end

   pdir = pdir * force

   local mass = phys:GetMass()
   if mass < 50 then
      pdir = pdir * (mass + 0.5) * (1 / 50)
   end

   phys:ApplyForceCenter(pdir)
end

function SWEP:GetRange(target)
   if IsValid(target) and target:IsWeapon() and allow_wep:GetBool() then
      return wep_range:GetFloat()
   elseif IsValid(target) and target:GetClass() == "prop_ragdoll" then
      return 75
   else
      return 100
   end
end

function SWEP:AllowPickup(target)
   local phys = target:GetPhysicsObject()
   local ply = self:GetOwner()

   return (IsValid(phys) and IsValid(ply) and
           (not phys:HasGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)) and
           phys:GetMass() < CARRY_WEIGHT_LIMIT and
           (not PlayerStandsOn(target)) and
           (target.CanPickup != false) and
           (target:GetClass() != "prop_ragdoll" or allow_rag:GetBool()) and
           ((not target:IsWeapon()) or allow_wep:GetBool()))
end

function SWEP:DoAttack(pickup)
	self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
	self.Weapon:SetNextSecondaryFire( CurTime() + self.Secondary.Delay )

	if IsValid(self.EntHolding) then
		self.Weapon:SendWeaponAnim( ACT_VM_MISSCENTER )
		if (not pickup) and self.EntHolding:GetClass() == "prop_ragdoll" then
			if not self:PinRagdoll() then
				self:Drop()
			end
		else
			self:Drop()
		end
		
		self.Weapon:SetNextSecondaryFire(CurTime() + 0.3)
		return
	end

	local ply = self.Owner
	local trace = ply:GetEyeTrace(MASK_SHOT)
	if IsValid(trace.Entity) then
		local ent = trace.Entity
		local phys = trace.Entity:GetPhysicsObject()
		if not IsValid(phys) or not phys:IsMoveable() or phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then
			return
		end

		if CLIENT then return end
		if pickup then
			if (ply:EyePos() - trace.HitPos):Length() < self:GetRange(ent) then
				if self:AllowPickup(ent) then
					self:Pickup()
					self.Weapon:SendWeaponAnim( ACT_VM_HITCENTER )
					local delay = (ent:GetClass() == "prop_ragdoll") and 0.8 or 0.5
					self.Weapon:SetNextSecondaryFire(CurTime() + delay)
					return
				else
					local is_ragdoll = trace.Entity:GetClass() == "prop_ragdoll"
					local ent = trace.Entity
					local phys = ent:GetPhysicsObject()
					local pdir = trace.Normal * -1

					if is_ragdoll then
						phys = ent:GetPhysicsObjectNum(trace.PhysicsBone)
					end

					if IsValid(phys) then
						self:MoveObject(phys, pdir, 6000, is_ragdoll)
						return
					end
				end
			end
		else
			if (ply:EyePos() - trace.HitPos):Length() < 100 then
				local phys = trace.Entity:GetPhysicsObject()
				if IsValid(phys) then
					if IsValid(phys) then
						local pdir = trace.Normal
						self:MoveObject(phys, pdir, 6000, (trace.Entity:GetClass() == "prop_ragdoll"))
						self.Weapon:SetNextPrimaryFire(CurTime() + 0.03)
					end
				end
			end
		end
	end
end

function SWEP:Pickup()
   if CLIENT or IsValid(self.EntHolding) then return end

   local ply = self.Owner
   local trace = ply:GetEyeTrace(MASK_SHOT)
   local ent = trace.Entity
   self.EntHolding = ent
   local entphys = ent:GetPhysicsObject()


   if IsValid(ent) and IsValid(entphys) then

      self.CarryHack = ents.Create("prop_physics")
      if IsValid(self.CarryHack) then
         self.CarryHack:SetPos(self.EntHolding:GetPos())

         self.CarryHack:SetModel("models/weapons/w_bugbait.mdl")

         self.CarryHack:SetColor(Color(50, 250, 50, 240))
         self.CarryHack:SetNoDraw(true)
         self.CarryHack:DrawShadow(false)

         self.CarryHack:SetHealth(999)
         self.CarryHack:SetOwner(ply)
         self.CarryHack:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
         self.CarryHack:SetSolid(SOLID_NONE)
         self.CarryHack:SetAngles(self.Owner:GetAngles())
         self.CarryHack:Spawn()
         if not self.EntHolding:IsWeapon() then
            self.PrevOwner = self.EntHolding:GetOwner()

            self.EntHolding:SetOwner(ply)
         end

         local phys = self.CarryHack:GetPhysicsObject()
         if IsValid(phys) then
            phys:SetMass(200)
            phys:SetDamping(0, 1000)
            phys:EnableGravity(false)
            phys:EnableCollisions(false)
            phys:EnableMotion(false)
            phys:AddGameFlag(FVPHYSICS_PLAYER_HELD)
         end

         entphys:AddGameFlag(FVPHYSICS_PLAYER_HELD)
         local bone = math.Clamp(trace.PhysicsBone, 0, 1)
         local max_force = prop_force:GetInt()

         if ent:GetClass() == "prop_ragdoll" then
            self.dt.carried_rag = ent

            bone = trace.PhysicsBone
            max_force = 0
         else
            self.dt.carried_rag = nil
         end

         self.Constr = constraint.Weld(self.CarryHack, self.EntHolding, 0, bone, max_force, true)


      end
   end
end

local down = Vector(0, 0, -1)
function SWEP:AllowEntityDrop()
   local ply = self.Owner
   local ent = self.CarryHack
   if (not IsValid(ply)) or (not IsValid(ent)) then return false end

   local ground = ply:GetGroundEntity()
   if ground and (ground:IsWorld() or IsValid(ground)) then return true end

   local diff = (ent:GetPos() - ply:GetShootPos()):GetNormalized()

   return down:Dot(diff) <= 0.75
end

function SWEP:Drop()
   if not self:CheckValidity() then return end
   if not self:AllowEntityDrop() then return end

   if SERVER then
      self.Constr:Remove()
      self.CarryHack:Remove()

      local ent = self.EntHolding

      local phys = ent:GetPhysicsObject()
      if IsValid(phys) then
         phys:EnableCollisions(true)
         phys:EnableGravity(true)
         phys:EnableDrag(true)
         phys:EnableMotion(true)
         phys:Wake()
         phys:ApplyForceCenter(self.Owner:GetAimVector() * 500)

         phys:ClearGameFlag(FVPHYSICS_PLAYER_HELD)
         phys:AddGameFlag(FVPHYSICS_WAS_THROWN)
      end

      if no_throw:GetBool() or ent:GetClass() == "prop_ragdoll" then
         KillVelocity(ent)
      end

      ent:SetPhysicsAttacker(self.Owner)

   end

   self:Reset()
end

local CONSTRAINT_TYPE = "Rope"

local function RagdollPinnedTakeDamage(rag, dmginfo)
   local att = dmginfo:GetAttacker()
   if not IsValid(att) then return end

   constraint.RemoveConstraints(rag, CONSTRAINT_TYPE)
   rag:PhysWake()

   rag:SetHealth(0)
   rag.is_pinned = false
end

function SWEP:PinRagdoll()
   if not pin_rag:GetBool() then return end
   if (not self.Owner:IsTraitor()) and (not pin_rag_inno:GetBool()) then return end

   local rag = self.EntHolding
   local ply = self.Owner

   local tr = util.TraceLine({start  = ply:EyePos(),
                              endpos = ply:EyePos() + (ply:GetAimVector() * PIN_RAG_RANGE),
                              filter = {ply, self, rag, self.CarryHack},
                              mask   = MASK_SOLID})

   if tr.HitWorld and (not tr.HitSky) then
      local bone = self.Constr.Bone2

      for _, c in pairs(constraint.FindConstraints(rag, CONSTRAINT_TYPE)) do
         if c.Bone1 == bone then
            c.Constraint:Remove()
         end
      end

      local bonephys = rag:GetPhysicsObjectNum(bone)
      if not IsValid(bonephys) then return end

      local bonepos = bonephys:GetPos()
      local attachpos = tr.HitPos
      local length = (bonepos - attachpos):Length() * 0.9

      bonepos = bonephys:WorldToLocal(bonepos)

      constraint.Rope(rag, tr.Entity, bone, 0, bonepos, attachpos,
                      length, length * 0.1, 6000,
                      1, "cable/rope", false)

      rag.is_pinned = true
      rag.OnPinnedDamage = RagdollPinnedTakeDamage

      rag:SetHealth(999999)

      self:Reset(true)
   end
end

function SWEP:SetupDataTables()
   self:DTVar("Bool", 0, "can_rag_pin")
   self:DTVar("Entity", 0, "carried_rag")
   return self.BaseClass.SetupDataTables(self)
end

if SERVER then
   function SWEP:Initialize()
      self.dt.can_rag_pin = pin_rag:GetBool()
      self.dt.carried_rag = nil

      return self.BaseClass.Initialize(self)
   end
end

if CLIENT then
   local draw = draw
   local util = util

   local PT = LANG.GetParamTranslation
   local key_params = {primaryfire = Key("+attack2", "RIGHT MOUSE")}
   function SWEP:DrawHUD()
      self.BaseClass.DrawHUD(self)

      if self.dt.can_rag_pin and IsValid(self.dt.carried_rag) and LocalPlayer():IsTraitor() then
         local client = LocalPlayer()

         local tr = util.TraceLine({start  = client:EyePos(),
                                    endpos = client:EyePos() + (client:GetAimVector() * PIN_RAG_RANGE),
                                    filter = {client, self, self.dt.carried_rag},
                                    mask   = MASK_SOLID})

         if tr.HitWorld and (not tr.HitSky) then
            draw.SimpleText(PT("magnet_help", key_params), "TabLarge", ScrW() / 2, ScrH() / 2 - 50, COLOR_RED, TEXT_ALIGN_CENTER)
         end
      end
   end
end


