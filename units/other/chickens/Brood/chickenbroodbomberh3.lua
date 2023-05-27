return {
	chickenbroodbomberh3 = {
		acceleration = 0.8,
		airhoverfactor = 0,
		attackrunlength = 32,
		bmcode = "1",
		brakerate = 0.1,
		buildcostenergy = 4550,
		buildcostmetal = 212,
		builder = false,
		buildpic = "chickens/chickenbroodbomber.DDS",
		buildtime = 9375,
		canattack = true,
		canfly = true,
		canguard = true,
		canland = true,
		canloopbackattack = true,
		canmove = true,
		canpatrol = true,
		canstop = "1",
		cansubmerge = true,
		capturable = false,
		category = "ALL MOBILE WEAPON NOTLAND VTOL NOTSUB NOTSHIP NOTHOVER CHICKEN",
		collide = true,
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = "70 70 70",
		collisionvolumetype = "sphere",
		cruisealt = 220,
		defaultmissiontype = "Standby",
		explodeas = "TALON_DEATH",
		footprintx = 3,
		footprintz = 3,
		hidedamage = 1,
		idleautoheal = 5,
		idletime = 0,
		maneuverleashlength = "20000",
		mass = 227.5,
		maxacc = 0.25,
		maxaileron = 0.025,
		maxbank = 0.8,
		maxdamage = 1500,
		maxelevator = 0.025,
		maxpitch = 0.75,
		maxrudder = 0.025,
		maxvelocity = 8,
		moverate1 = "32",
		noautofire = false,
		nochasecategory = "VTOL",
		objectname = "Chickens/chickenbroodbomber.s3o",
		script = "Chickens/chickenf1.cob",
		seismicsignature = 0,
		selfdestructas = "TALON_DEATH",
		side = "THUNDERBIRDS",
		sightdistance = 1000,
		smoothanim = true,
		speedtofront = 0.07,
		steeringmode = "2",
		tedclass = "VTOL",
		turninplace = true,
		turnradius = 64,
		turnrate = 1600,
		unitname = "chickenbroodbomber",
		usesmoothmesh = true,
		wingangle = 0.06593,
		wingdrag = 0.835,
		workertime = 0,
		customparams = {
			subfolder = "other/chickens",
			model_author = "KDR_11k, Beherith",
			normalmaps = "yes",
			normaltex = "unittextures/chicken_l_normals.png",
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:blood_spray",
				[2] = "custom:blood_explode",
				[3] = "custom:dirt",
			},
			pieceexplosiongenerators = {
				[1] = "blood_spray",
				[2] = "blood_spray",
				[3] = "blood_spray",
			},
		},
		weapondefs = {
			bloodyeggs = {
				accuracy = 500000,
				collidefriendly = 0,
				collidefeature = 0,
				avoidfeature = 0,
				avoidfriendly = 0,
				areaofeffect = 128,
				burst = 2,
				burstrate = 0.5,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.45,
				explosiongenerator = "custom:dirt",
				impulseboost = 1,
				impulsefactor = 1,
				interceptedbyshieldtype = 0,
				model = "Chickens/s_chickenboss2_white.s3o",
				mygravity = 0.5,
				name = "GooBombs",
				noselfdamage = true,
				range = 1500,
				reloadtime = 0.1,
				soundhit = "smallchickenattack",
				soundstart = "alien_bombrel",
				sprayangle = 1000000,
				weapontype = "AircraftBomb",
				damage = {
					default = 1,
				},
				customparams = {
					spawns_name = "chickenh3",
					spawns_surface = "LAND SEA", -- Available: "LAND SEA"
				},
			},
		},
		weapons = {
			[1] = {
				def = "bloodyeggs",
			},
		},
	},
}
