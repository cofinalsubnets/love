; src/apps/pic/cli.l -- the verbs: classic pic, grap and chem, troff preprocessors each
(module '(pic gpic-main gp-run grap-main gr-run chem-main ch-run)
(borrow 'cli)
(cite 'verbs 'enlist 'pic (udoor 'pic (urun gpic-main) "usage: pic [-nCSU] [-t [-cz]] [FILE..]" 1 1) (),
 cite 'verbs 'enlist 'grap (udoor 'grap (urun grap-main) "usage: grap [FILE..]" 1 1) (),
 cite 'verbs 'enlist 'chem (udoor 'chem (urun chem-main) "usage: chem [FILE..]" 1 1) ())
) ; module pic
