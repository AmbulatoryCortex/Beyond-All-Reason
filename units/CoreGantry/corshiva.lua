return {
	corshiva = {
		acceleration = 0.06,
		brakerate = 0.714,
		buildcostenergy = 23000,
		buildcostmetal = 1600,
		buildpic = "CORSHIVA.DDS",
		buildtime = 30609,
		canmove = true,
		category = "KBOT WEAPON ALL NOTSUB NOTAIR NOTHOVER SURFACE CANBEUW",
		collisionvolumeoffsets = "0 -4 -6",
		collisionvolumescales = "61 45 67",
		collisionvolumetype = "Ell",
		corpse = "DEAD",
		description = "Amphibious Siege Mech",
		explodeas = "hugeExplosionGeneric-phib",
		footprintx = 4,
		footprintz = 4,
		idleautoheal = 15,
		idletime = 1800,
		mass = 200000,
		maxdamage = 8500,
		maxslope = 36,
		maxvelocity = 1.61,
		maxwaterdepth = 32,
		movementclass = "HAKBOT4",
		name = "Shiva",
		nochasecategory = "VTOL",
		objectname = "CORSHIVA",
		seismicsignature = 0,
		selfdestructas = "hugeExplosionGenericSelfd-phib",
		sightdistance = 520,
		turninplaceanglelimit = 140,
		turninplacespeedlimit = 1.0626,
		turnrate = 616,
		upright = true,
		customparams = {
			techlevel = 3,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "2.34152984619 -0.363798242187 4.68096923828",
				collisionvolumescales = "48.4013214111 35.5686035156 49.8471069336",
				collisionvolumetype = "Box",
				damage = 1500,
				description = "Shiva Wreckage",
				energy = 0,
				featuredead = "HEAP",
				featurereclamate = "SMUDGE01",
				footprintx = 3,
				footprintz = 3,
				height = 10,
				hitdensity = 100,
				metal = 937,
				object = "CORSHIVA_DEAD",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
			heap = {
				blocking = false,
				category = "heaps",
				damage = 2000,
				description = "Shiva Heap",
				energy = 0,
				featurereclamate = "SMUDGE01",
				footprintx = 3,
				footprintz = 3,
				height = 4,
				hitdensity = 100,
				metal = 375,
				object = "3X3F",
                collisionvolumescales = "55.0 4.0 6.0",
                collisionvolumetype = "cylY",
                reclaimable = true,
				resurrectable = 0,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
		},
		sfxtypes = { 
 			pieceExplosionGenerators = { 
				"deathceg2",
				"deathceg3",
				"deathceg4",
			},
			explosiongenerators = {
				[1] = "custom:barrelshot-large",
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
			cant = {
				[1] = "cantdo4",
			},
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			ok = {
				[1] = "mavbok1",
			},
			select = {
				[1] = "mavbsel1",
			},
		},
		weapondefs = {
			shiva_gun = {
				areaofeffect = 176,
				avoidfeature = false,
				craterareaofeffect = 176,
				craterboost = 0,
				cratermult = 0,
				explosiongenerator = "custom:genericshellexplosion-large",
				gravityaffected = "true",
				impulseboost = 0.123,
				impulsefactor = 0.123,
				name = "HeavyCannon",
				noselfdamage = true,
				range = 650,
				reloadtime = 3,
				soundhit = "xplomed4",
				soundhitwet = "splslrg",
				soundhitwetvolume = 0.5,
				soundstart = "cannhvy2",
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 310,
				damage = {
					bombers = 55,
					default = 900,
					fighters = 55,
					subs = 5,
					vtol = 55,
				},
			},
			shiva_rocket = {
				areaofeffect = 60,
				avoidfeature = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.5,
				cegTag = "missiletrailmedium-starburst",
				explosiongenerator = "custom:genericshellexplosion-large-bomb",
				firestarter = 100,
				flighttime = 10,
				impulseboost = 0.123,
				impulsefactor = 0.123,
				metalpershot = 0,
				model = "corkbmissl1",
				name = "HeavyRockets",
				noselfdamage = true,
				range = 800,
				reloadtime = 7,
				soundhit = "xplomed4",
				soundhitwet = "splssml",
				soundhitwetvolume = 0.5,
				soundstart = "Rockhvy1",
				smoketrail = false,
                texture1 = "trans",
				texture2 = "null",
				texture3 = "null",
				turnrate = 28384,
				weaponacceleration = 100,
				weapontimer = 2,
				weapontype = "StarburstLauncher",
				weaponvelocity = 800,
				damage = {
					default = 750,
					subs = 5,
				},
				customparams = {
                    light_mult = 4.5,
                    light_radius_mult = 1,
                    light_color = "1 0.66 0.25",
                    expl_light_mult = 1.25,
                    expl_light_radius_mult = 1.3,
                    expl_light_life_mult = 1.3,
					expl_light_color = "1 0.5 0.05",
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "GROUNDSCOUT",
				def = "SHIVA_GUN",
				onlytargetcategory = "SURFACE",
			},
			[3] = {
				badtargetcategory = "GROUNDSCOUT",
				def = "SHIVA_ROCKET",
				onlytargetcategory = "SURFACE",
			},
		},
	},
}
