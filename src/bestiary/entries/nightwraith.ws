
class RER_BestiaryNightwraith extends RER_BestiaryEntry {
  public function init() {
    this.type = CreatureNIGHTWRAITH;
    this.menu_name = 'NightWraiths';

    

  this.template_list.templates.PushBack(
    makeEnemyTemplate(
      "characters\npc_entities\monsters\nightwraith_lvl1.w2ent",,,
      "gameplay\journal\bestiary\bestiarymoonwright.journal"
    )
  );
  this.template_list.templates.PushBack(
    makeEnemyTemplate(
      "characters\npc_entities\monsters\nightwraith_lvl2.w2ent",,,
      "gameplay\journal\bestiary\bestiarymoonwright.journal"
    )
  );
  this.template_list.templates.PushBack(
    makeEnemyTemplate(
      "characters\npc_entities\monsters\nightwraith_lvl3.w2ent",,,
      "gameplay\journal\bestiary\bestiarymoonwright.journal"
    )
  );

  if(theGame.GetDLCManager().IsEP2Available() && theGame.GetDLCManager().IsEP2Enabled()){
    this.template_list.templates.PushBack(
      makeEnemyTemplate(
        "dlc\bob\data\characters\npc_entities\monsters\nightwraith_banshee.w2ent",,,
        "dlc\bob\journal\bestiary\beanshie.journal"
      )
    );
  }

    this.template_list.difficulty_factor.minimum_count_easy = 1;
    this.template_list.difficulty_factor.maximum_count_easy = 1;
    this.template_list.difficulty_factor.minimum_count_medium = 1;
    this.template_list.difficulty_factor.maximum_count_medium = 1;
    this.template_list.difficulty_factor.minimum_count_hard = 1;
    this.template_list.difficulty_factor.maximum_count_hard = 1;

  

    this.trophy_names.PushBack('modrer_nightwraith_trophy_low');
    this.trophy_names.PushBack('modrer_nightwraith_trophy_medium');
    this.trophy_names.PushBack('modrer_nightwraith_trophy_high');

  }

  public function setCreaturePreferences(preferences: RER_CreaturePreferences, encounter_type: EncounterType): RER_CreaturePreferences{
    return super.setCreaturePreferences(preferences, encounter_type);
  }
}
