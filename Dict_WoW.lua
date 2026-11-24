local _, CK = ...
CK.Dicts = CK.Dicts or {}

-- Vocabulaire de chat WoW (FR + EN), toujours chargé. Русский словарь чата: в конце.
CK.Dicts.wow = [[
lfg lfm lf1m lf2m lf3m gg wp gz gratz grats afk brb omw inv invite invit
groupe grp guilde guild raid donjon donjons instance quête quêtes quete quest
tank heal healer heals soigneur soins dps cac distance
loot need greed pass roll ninja
pull wipe boss trash mob mobs pack aggro agro kite
buff buffs debuff rez res résu ress mana vie hp
hdv ah po pa pc gold silver copper stuff équipement set craft farm farmer
xp up lvl level niveau lvlup
wtb wts wtt mp pst whisp
sort sorts talent talents spé spec build
monture mount vol volant
rare épique epic légendaire legendary vert bleu violet
classe race horde alliance
guerrier paladin chasseur voleur prêtre chaman mage démoniste druide
warrior pala hunt hunter rogue priest shaman sham lock warlock druid
fufu voleur druide
nain humain elfe gnome orc troll tauren mort-vivant undead
orgrimmar hurlevent forgefer darnassus fossoyeuse pitons-du-tonnerre
stormwind ironforge undercity thunder bluff
mortemines deadmines stratholme strat scholomance scholo rfc rfk rfd sm zg mc
bwl ony onyxia naxx naxxramas aq brd lbrs ubrs dm wc sfk uldaman ulda zf mara
maraudon bfd stocks gnomeregan gnomer
pvp pve bg bgs goulet arathi alterac champ bataille duel
heal-moi rez-moi inv-moi
ready rdy go wait attendez stop
merci thx ty thanks np
mdr lol ptdr xd jsp jpp tkt stp svp slt bjr bsr cc coucou dsl pk pq bcp mtn tlm
qqn qqch osef oklm wesh ouais nan bref ok okay
привет прив ку хай здорова здарова народ ребята парни мужики спс спсб гж поздравляю изи изиш
молодец молодцы молодца красавчик красавчики красотка красотки угу ага неа жиза жича лфг лфм лфс
лф1м лф2м лф3м ищу ищем нужен нужна нужно нужны инв инвай инвайт инвайтни инвайтните кинь киньте
дай дайте пустите примите добавь добавьте пати патя патю патей группа группе группу группой
групп гр рейд рейде рейду рейдом рейда гильдия гильдию гильде гильды гильд гильдейский
гильдейские гильдейская танк танка танкую танкуй танки танкист танкиста хил хила хилу хилер хилл
хилы хилю хилить хиль хильни хилку дпс дд дды дпсер вар вара вару варом воин воина воину пал
пала палу паладин паладина паладину охотник охотника охотнику хант ханта ханту рога рогу рогом
рог разбойник разбойника разбойнику маг мага магу магом лока локу локом лок чернокнижник
чернокнижника чернокнижнику прист присту пристом жрец жреца жрецу шам шама шаму шаман шамана
шаману дру друида друид друду друдом друиду мишка мишку кот кота коту пул пулить пулю пуль
пулюнул пулни пулл агро агрю агри агрит агрим агрить сбрось сбросьте стяни стяните сорви сорвал
сорвите моб моба мобу мобы мобов мобах элитка элитки босс босса боссу боссы боссов боссе треш
трешка трешки пак паки паков кд кулдаун кулдауны кулдауна баф бафы бафни бафните бафф баффы
баффни баффните дебафф дебаффы пот поты потов зелье зелья эликсир эликсира флакон флакона свиток
свитка бинты бинт еда еды фуд жратва вода воды напиток хп мана маны маной опыта опыт экспа лвл
левел уровень апнул апну апнем апайте лвлап лут лутай лутать лутни лутните лутнул нед грид пасс
ролл ролльте ролльнул вайп вайпанули вайпнулись вайпнусь рип рипнул рипнули ваншот ваншотнули
бурст бурстни кайт кайти интерапт интераптни прерви прервать рес ресс ресни ресните воскресни
воскресите беги бегите тапай тапайте тапи сбегай сбегайте стой сто тормози остановись данж
данжик данжа данжу данже данжам данжах инста инсту инсты квест квесты квеста квесту квестик кв
задание задания заданию задании спек билд таланты талант шмот шмотки шмоток гир гира экип крафт
скрафтил скрафть фарм фармлю фарму зафармить голда голду голды золото серебро медь аук аука ах
копи крепость тюрьма гномреган иглошкурые курганы монастырь ульдаман ульд фаррак мародон храм
глубины стратхольм страт некроситет некро забытый город разлом стенания пучина ония ониксия ядро
логово наксрамас накс анкираж ущелье низина арати долина орда орду орды орде альянс альянса орга
оргу орге оргриммар шторм штормград штормграда стальгорн дарнас подгород подгороде громовой утес
утёс пвп пве бг арена дуэль ганк ганкнули ганкни нуб нубик нубас читер чит читы бот боты токсик
токсичная имба имбовая имбовость чар чара чаром чарик монт маунт маунты фармешь дс дискорд диск
стрим стримлю тайм мин минутку сек секунду афк брб отошел отошла отвлекся вернусь
]]
