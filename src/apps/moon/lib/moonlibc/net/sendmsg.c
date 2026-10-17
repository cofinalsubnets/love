#include "../impl.h"

/* the BSDs' msghdr has int-wide lengths and their cmsg an int-wide head (__love_cmh
 * says where its data sits), so each head is laid again in the BSD's shape. under SOL_SOCKET
 * only SCM_RIGHTS is spelled; an unmapped type refuses loudly. control rides
 * a fixed scratch -- a bigger one refuses, never a torn walk. */
long sendmsg(int fd, struct msghdr const *m, int fl) {
  if (__love_osv < 2) return er(sc3(NR_sendmsg, fd, (long) m, fl));
  struct sockaddr_storage sa;
  unsigned char cb[256];
  struct __fb_msghdr f = {0, 0, 0, 0, 0, 0, 0, 0, 0};
  f.iov = m->msg_iov; f.iovlen = (int) m->msg_iovlen;
  if (m->msg_name) {
    if (m->msg_namelen > sizeof sa) return er(-EINVAL);
    f.namelen = __love_sain(m->msg_name, m->msg_namelen, &sa);
    f.name = &sa; }
  unsigned long cn = m->msg_controllen;
  if (cn) {
    unsigned char const *c = m->msg_control;
    unsigned long at = 0, bt = 0, ch = CMSG_ALIGN(sizeof(struct cmsghdr));
    unsigned long bh = __love_cmh(), bal = __love_cma() - 1;
    if (!c) return er(-EINVAL);
    memset(cb, 0, sizeof cb);
    while (at + ch <= cn) {
      struct cmsghdr const *h = (struct cmsghdr const*) (c + at);
      unsigned long l = h->cmsg_len, dl = l - ch;
      int lv = h->cmsg_level, ty = h->cmsg_type;
      if (l < ch || l > cn - at || bt + bh + dl > sizeof cb) return er(-EINVAL);
      if (lv == 1) { if (ty != 1) return er(-EINVAL); lv = 0xffff; }
      if (lv == 41 && ty == 52) ty = 47;  /* IPV6_HOPLIMIT */
      *(unsigned int*) (cb + bt) = (unsigned int) (bh + dl);
      *(int*) (cb + bt + 4) = lv;
      *(int*) (cb + bt + 8) = ty;
      memcpy(cb + bt + bh, c + at + ch, dl);
      at += CMSG_ALIGN(l);
      bt += (bh + dl + bal) & ~bal; }
    f.control = cb; f.controllen = (unsigned int) bt; }
  return er(sc3(NR_sendmsg, fd, (long) &f, (long) __love_msgfb(fl))); }
