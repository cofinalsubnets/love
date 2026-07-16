#ifndef _AI_LIBINTL_H
#define _AI_LIBINTL_H
/* freestanding libintl for cc: no message catalogs -- gettext is the identity, the
 * domain/binding calls are no-ops. matches a build with NLS enabled but no libintl. */
#define gettext(Msgid)                     (Msgid)
#define dgettext(Domain, Msgid)            (Msgid)
#define dcgettext(Domain, Msgid, Category) (Msgid)
#define ngettext(Msgid1, Msgid2, N)        ((N) == 1 ? (Msgid1) : (Msgid2))
#define dngettext(Dom, M1, M2, N)          ((N) == 1 ? (M1) : (M2))
#define textdomain(Domain)                 ((char *)0)
#define bindtextdomain(Domain, Dir)        ((char *)0)
#define bind_textdomain_codeset(Dom, Cs)   ((char *)0)
#endif
