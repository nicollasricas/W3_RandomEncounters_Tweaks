class CRandomEncounterInitializer extends CEntityMod {
  default modName = 'Random Encounters';
  default modAuthor = "erxv";
  default modUrl = "http://www.nexusmods.com/witcher3/mods/785?";
  default modVersion = '1.31';

  default logLevel = MLOG_DEBUG;

  default template = "dlc\modtemplates\randomencounterdlc\data\re_initializer.w2ent";
}


function modCreate_RandomEncounters() : CMod {
  return new CRandomEncounterInitializer in thePlayer;
}

statemachine class CRandomEncounters extends CEntity {
  private	var rExtra: CModRExtra;
  private var settings: RE_Settings;
  private var resources: RE_Resources;

  private var ticks_before_spawn: int;

  event OnSpawned(spawn_data: SEntitySpawnData) {
    var ents: array<CEntity>;

    theGame.GetEntitiesByTag('RandomEncounterTag', ents);

    if (ents.Size() > 1) {
      this.Destroy();

      return true;
    }
    
    this.AddTag('RandomEncounterTag');

    theInput.RegisterListener(this, 'OnRefreshSettings', 'RefreshRESetting');
    theInput.RegisterListener(this, 'OnSpawnMonster', 'RandomEncounter');

    super.OnSpawned(spawn_data);

    rExtra = new CModRExtra in this;
    settings = new RE_Settings in this;
    resources = new RE_Resources in this;

    this.initiateRandomEncounters();
  }

  event OnRefreshSettings(action: SInputAction) {
    if (IsPressed(action)) {
      this.settings.loadXMLSettings(true);
    }
  }

  private function initiateRandomEncounters() {
    this.settings.loadXMLSettings(false);
    this.resources.load_resources();

    this.ticks_before_spawn = this.calculateRandomTicksBeforeSpawn();

    AddTimer('onceReady', 3.0, false);
    AddTimer('randomEncounterTick', 1.0, true);
  }

  timer function onceReady(optional delta: float, optional id: Int32) {
    displayRandomEncounterEnabledNotification();
  }

  timer function randomEncounterTick(optional delta: float, optional id: Int32) {
    if (this.ticks_before_spawn < 0) {
      // adding a timer to avoid spending too much time in this
      // supposedly quick function.
      AddTimer('triggerCreaturesSpawn', 0.1, false);
    }

    this.ticks_before_spawn -= 1;
  }

  private function calculateRandomTicksBeforeSpawn(): int {
    if (this.settings.customFrequency) {
      if (theGame.envMgr.IsNight()) {
        return RandRange(this.settings.customNightMin, this.settings.customNightMax);
      }

      return RandRange(this.settings.customDayMin, this.settings.customDayMax);
    }
    
    if (theGame.envMgr.IsNight()) {
      switch (this.settings.chanceNight) {
        case 1:
          return RandRange(1400, 3200);
          break;
        
        case 2:
          return RandRange(800, 1600);
          break;

        case 3:
          return RandRange(500, 900);
          break;
      }

      return 99999;
    }

    switch (this.settings.chanceDay) {
      case 1:
        return RandRange(1400, 3900);
        break;

      case 2:
        return RandRange(800, 1800);
        break;

      case 3:
        return RandRange(500, 1100);
        break;
    }

    return 99999;
  }

  timer function triggerCreaturesSpawn(optional delta: float, optional id: Int32) {
    var current_state: CName;
    var is_meditating: bool;
    var current_zone: EREZone;
    var choice : array<EEncounterType>;
    var flying_active, ground_active, human_active, group_active, wild_hunt_active: int;
    var i: int;
    var picked_entity_type: int;
    
    current_zone = this.rExtra.getCustomZone(thePlayer.GetWorldPosition());

    current_state = thePlayer.GetCurrentStateName();
    is_meditating = current_state == 'Meditation' && current_state == 'MeditationWaiting';

    if (is_meditating 
     || thePlayer.IsInInterior()
     || thePlayer.IsInCombat()
     || thePlayer.IsUsingBoat()
     || thePlayer.IsInFistFightMiniGame()
     || thePlayer.IsSwimming()
     || thePlayer.IsInNonGameplayCutscene()
     || thePlayer.IsInGameplayScene()
     || theGame.IsDialogOrCutscenePlaying()
     || theGame.IsCurrentlyPlayingNonGameplayScene()
     || theGame.IsFading()
     || theGame.IsBlackscreen()) {
      // postpone the spawning for later
      this.ticks_before_spawn = RandRange(30, 120);

      return;
    }

    if (current_zone == REZ_CITY && !this.settings.cityBruxa && !this.settings.citySpawn) {
      return;
    }

    if (theGame.envMgr.IsNight()) {
      for (i = 0; i < this.settings.isGroundActiveN; i += 1) {
        choice.PushBack(ET_GROUND);
      }

      // TODO: add inForest factor, maybe 0.5?
      for (i = 0; i < this.settings.isFlyingActiveN; i += 1) {
        choice.PushBack(ET_FLYING);
      }

      for (i = 0; i < this.settings.isHumanActiveN; i += 1) {
        choice.PushBack(ET_HUMAN);
      }

      for (i = 0; i < this.settings.isGroupActiveN; i += 1) {
        choice.PushBack(ET_GROUP);
      }

      for (i = 0; i < this.settings.isWildHuntActiveN; i += 1) {
        choice.PushBack(ET_WILDHUNT);
      }
    }
    else {
      for (i = 0; i < this.settings.isGroundActiveD; i += 1) {
        choice.PushBack(ET_GROUND);
      }

      // TODO: add inForest factor, maybe 0.5?
      for (i = 0; i < this.settings.isFlyingActiveD; i += 1) {
        choice.PushBack(ET_FLYING);
      }

      for (i = 0; i < this.settings.isHumanActiveD; i += 1) {
        choice.PushBack(ET_HUMAN);
      }

      for (i = 0; i < this.settings.isGroupActiveD; i += 1) {
        choice.PushBack(ET_GROUP);
      }

      for (i = 0; i < this.settings.isWildHuntActiveD; i += 1) {
        choice.PushBack(ET_WILDHUNT);
      }
    }

    if (choice.Size() > 0) {
      picked_entity_type = choice[RandRange(choice.Size())];

      LogChannel('modRandomEncounter', "spawning humans");

      this.trySpawnHuman();

      switch (picked_entity_type) {
        case ET_GROUND:
          LogChannel('modRandomEncounter', "spawning type ET_GROUND ");
          break;

        case ET_FLYING:
          LogChannel('modRandomEncounter', "spawning type ET_FLYING ");
          break;

        case ET_HUMAN:
          LogChannel('modRandomEncounter', "spawning type ET_HUMAN ");
          break;

        case ET_GROUP:
          LogChannel('modRandomEncounter', "spawning type ET_GROUP ");
          break;

        case ET_WILDHUNT:
          LogChannel('modRandomEncounter', "spawning type ET_WILDHUNT ");
          break;
      }
    }
  }

  private function trySpawnHuman(): bool {
    var human_template: CEntityTemplate;
    var number_of_humans: int;
    var current_area: string;
    var choice: array<EHumanType>;
    var picked_human_type: EHumanType;
    var initial_human_position: Vector;
    var current_human_position: Vector;
    var template_human_array: array<SEnemyTemplate>;
    var i: int;

    current_area = AreaTypeToName(theGame.GetCommonMapManager().GetCurrentArea());

    if (current_area == "prolog_village") {
      for (i=0; i<3; i+=1) {
        choice.PushBack(HT_BANDIT);
      }
      
      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_CANNIBAL);
      }
      
      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_RENEGADE);
      }
    }
    else if (current_area == "skellige") {
      for (i=0; i<3; i+=1) {
        choice.PushBack(HT_SKELBANDIT);
      }
      
      for (i=0; i<3; i+=1) {
        choice.PushBack(HT_SKELBANDIT2);
      }
  
      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_SKELPIRATE);
      }
    }
    else if (current_area == "kaer_morhen") {
      for (i=0; i<3; i+=1) {
        choice.PushBack(HT_BANDIT);
      }

      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_CANNIBAL);
      }

      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_RENEGADE);
      }
    }
    else if (current_area == "novigrad" || current_area == "no_mans_land") {
      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_NOVBANDIT);
      }

      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_PIRATE);
      }

      for (i=0; i<3; i+=1) {
        choice.PushBack(HT_BANDIT);
      }

      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_NILFGAARDIAN);
      }

      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_CANNIBAL);
      }

      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_RENEGADE);
      }

      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_WITCHHUNTER);
      }
    }
    else if (current_area == "bob") {
      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_NOVBANDIT);
      }

      for (i=0; i<4; i+=1) {
        choice.PushBack(HT_BANDIT);
      }

      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_NILFGAARDIAN);
      }

      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_CANNIBAL);
      }

      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_RENEGADE);
      }
    }
    else {
      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_NOVBANDIT);
      }

      for (i=0; i<4; i+=1) {
        choice.PushBack(HT_BANDIT);
      }

      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_NILFGAARDIAN);
      }

      for (i=0; i<1; i+=1) {
        choice.PushBack(HT_CANNIBAL);
      }

      for (i=0; i<2; i+=1) {
        choice.PushBack(HT_RENEGADE);
      }
    }

    picked_human_type = choice[RandRange(choice.Size())];

    if (picked_human_type == HT_BANDIT) {
      template_human_array = this.resources.bandit;
    }
    else if (picked_human_type == HT_NOVBANDIT) {
      template_human_array = this.resources.novbandit;
    }
    else if (picked_human_type == HT_SKELBANDIT) {
      template_human_array = this.resources.skelbandit;
    }
    else if (picked_human_type == HT_SKELBANDIT2) {
      template_human_array = this.resources.skel2bandit;
    }
    else if (picked_human_type == HT_CANNIBAL) {
      template_human_array = this.resources.cannibal;
    }
    else if (picked_human_type == HT_RENEGADE) {
      template_human_array = this.resources.renegade;
    }
    else if (picked_human_type == HT_PIRATE) {
      template_human_array = this.resources.pirate;
    }
    else if (picked_human_type == HT_SKELPIRATE) {
      template_human_array = this.resources.skelpirate;
    }
    else if (picked_human_type == HT_NILFGAARDIAN) {
      template_human_array = this.resources.nilf;
    }
    else if (picked_human_type == HT_WITCHHUNTER) {
      template_human_array = this.resources.whunter;
    }
    else {
      template_human_array = this.resources.bandit;
    }

    number_of_humans = RandRange(
      4 + this.settings.selectedDifficulty,
      6 + this.settings.selectedDifficulty
    );

    LogChannel('modRandomEncounters', "number of humans: " + number_of_humans);

    this.PrepareEnemyTemplate(template_human_array);

    if (!this.getInitialHumanPosition(initial_human_position)) {
      // could net get a proper initial position
      return false;
    }

    this.spawnEntities(
      (CEntityTemplate)LoadResource(this.ObtainTemplateForEnemy(template_human_array), true),
      initial_human_position,
      number_of_humans
    );

    return true;
  }

  protected function ObtainTemplateForEnemy( tempArray : array<SEnemyTemplate> ) : string
  {
    var i : int;
    var _tempArray : array<SEnemyTemplate>;
    var _templateid : int;
    var _template : SEnemyTemplate;

    for (i = 0; i < tempArray.Size(); i += 1)
    {
      if (tempArray[i].max < 0 || tempArray[i].count < tempArray[i].max)
      {
        _tempArray.PushBack(tempArray[i]);
      }
    }

    _templateid = RandRange(_tempArray.Size());
    _template = _tempArray[_templateid];

    for (i = 0; i < tempArray.Size(); i += 1)
    {
      if (tempArray[i] == _template)
      {
        tempArray[i].count += 1;
        break;
      }
    }

    return _template.template;
  }

  private function spawnEntities(entity_template: CEntityTemplate, initial_position: Vector, optional quantity: int) {
    var ent: CEntity;
    var player, pos_fin, normal: Vector;
    var rot: EulerAngles;
    var i, sign: int;
    var s, r, x, y: float;
    var createEntityHelper: CCreateEntityHelper;

    entity_template = (CEntityTemplate)LoadResource("dlc\modtemplates\randomencounterdlc\data\re_human.w2ent", true);
    
    quantity = Max(quantity, 1);

    LogChannel('modRandomEncounters', "spawning " + quantity + " entities");
	
    rot = thePlayer.GetWorldRotation();	
    // rot.Yaw += 180;		//the front placed entities will face the player

    player = thePlayer.GetWorldPosition();

    //const values used in the loop
    pos_fin.Z = initial_position.Z;			//final spawn pos
    s = quantity / 0.2;			//maintain a constant density of 0.2 unit per m2
    r = SqrtF(s/Pi());

    for (i = 0; i < quantity; i += 1) {
      x = RandF() * r;			//add random value within range to X
		  y = RandF() * (r - x);		//add random value to Y so that the point is within the disk

      if(RandRange(2))					//randomly select the sign for misplacement
        sign = 1;
      else
        sign = -1;
        
      pos_fin.X = initial_position.X + sign * x;	//final X pos
      
      if(RandRange(2))					//randomly select the sign for misplacement
        sign = 1;
      else
        sign = -1;
        
      pos_fin.Y = initial_position.Y + sign * y;	//final Y pos

      theGame.GetWorld().StaticTrace( pos_fin + Vector(0,0,3), pos_fin - Vector(0,0,3), pos_fin, normal);


      ent = theGame.CreateEntity(entity_template, pos_fin - Vector(0, 0, 2), rot, true, false, true, PM_Persist);

      // createEntityHelper = new CCreateEntityHelper in this;
      // createEntityHelper.SetPostAttachedCallback( this, 'onEntitySpawned' );

      // LogChannel('modRandomEncounters', "player position" + thePlayer.GetWorldPosition());
      LogChannel('modRandomEncounters', "player at " + player.X + " " + player.Y + " " + player.Z);
      LogChannel('modRandomEncounters', "spawning entity at " + pos_fin.X + " " + pos_fin.Y + " " + pos_fin.Z);

      // theGame.CreateEntityAsync(createEntityHelper, entity_template, pos_fin, rot, true, false, false, PM_DontPersist);
      ((CNewNPC)ent).SetLevel(GetWitcherPlayer().GetLevel());
      ((CNewNPC)ent).NoticeActor(thePlayer);
      ((CActor)ent).SetTemporaryAttitudeGroup( 'hostile_to_player', AGP_Default );
    }
  }

  function onEntitySpawned(entity: CEntity) {
    var summon: CNewNPC;
    LogChannel('modRandomEncounters', "1 entity spawned");
    

    summon = ( CNewNPC ) entity;

    summon.SetLevel(GetWitcherPlayer().GetLevel());
    summon.NoticeActor(thePlayer);
    summon.SetTemporaryAttitudeGroup('hostile_to_player', AGP_Default);
  }

  private function getInitialHumanPosition(out initial_pos: Vector, optional distance: float) : bool {
    var collision_normal: Vector;
    var camera_direction: Vector;
    var player_position: Vector;

    camera_direction = theCamera.GetCameraDirection();

    if (distance == 0.0) {
      distance = 3.0; // meters
    }

    camera_direction.X *= distance;
    camera_direction.Y *= distance;

    player_position = thePlayer.GetWorldPosition();

    initial_pos = player_position + camera_direction;
    initial_pos.Z = player_position.Z;

    return theGame
      .GetWorld()
      .StaticTrace(
        initial_pos + 5,// Vector(0,0,5),
        initial_pos - 5,//Vector(0,0,5),
        initial_pos,
        collision_normal
      );

    // var i: int;
    // var pos: Vector;
    // var z: float;

    // for (i = 0; i < 30; i += 1) {
    //   pos = thePlayer.GetWorldPosition() + VecConeRand(theCamera.GetCameraHeading(), -170, -20, -25);

    //   FixZAxis(pos);

    //   if (!this.canSpawnEnt(pos)) {
    //     return false;
    //   }

    //   initial_pos = pos;

    //   return true;
    // }
  }

  protected function PrepareEnemyTemplate(arr: array<SEnemyTemplate>) {
    var i: int;

    for (i = 0; i < arr.Size(); i += 1) {
      arr[i].count = 0;
    }
  }

  public function canSpawnEnt(pos : Vector) : bool {
    var template : CEntityTemplate;
    var rot : EulerAngles;
    var canSpawn : bool;
    var ract : CActor;
    var currentArea : string;
    var inSettlement : bool;

    canSpawn = false;

    template = (CEntityTemplate)LoadResource( "characters\npc_entities\animals\hare.w2ent", true );	
    ract = (CActor)theGame.CreateEntity(template, pos, rot);
    
    ((CNewNPC)ract).SetGameplayVisibility(false);
    ((CNewNPC)ract).SetVisibility(false);		
    
    ract.EnableCharacterCollisions(false);
    ract.EnableDynamicCollisions(false);
    ract.EnableStaticCollisions(false);
    ract.SetImmortalityMode(AIM_Invulnerable, AIC_Default);

    inSettlement = ract.TestIsInSettlement();

    if (!inSettlement
      && pos.Z >= theGame.GetWorld().GetWaterLevel(pos, true)
      && !((CNewNPC)ract).IsInInterior()) {

      canSpawn = true;
    }

    ract.Destroy();

    return canSpawn;
  }

}

function FixZAxis(out pos : Vector) {
    var world : CWorld;
    var z : float;

    world = theGame.GetWorld();

    if (world.NavigationComputeZ(pos, pos.Z - 128, pos.Z + 128, z)) {
      pos.Z = z;
    }

    if (world.PhysicsCorrectZ(pos, z)) {
      pos.Z = z;
    }
}