#include "../impl.h"

/* sendmsg's mirror: the kernel fills the BSD twins in our scratch, the heads
 * rewrite back to the canon in the caller's buffers. control past the scratch
 * comes back MSG_CTRUNC -- the kernel's own word for it. */
long recvmsg(int fd, struct msghdr *m, int fl) {
  if (__love_osv < 2) return er(sc3(NR_recvmsg, fd, (long) m, fl));
  if (fl & MSG_ERRQUEUE) return er(-EAGAIN);   /* linux's alone: a bsd has no error queue */
  struct sockaddr_storage sa;
  unsigned char cb[256];
  struct __fb_msghdr f = {0, 0, 0, 0, 0, 0, 0, 0, 0};
  f.iov = m->msg_iov; f.iovlen = (int) m->msg_iovlen;
  if (m->msg_name) { f.name = &sa; f.namelen = sizeof sa; }
  unsigned long cap = m->msg_controllen;
  if (m->msg_control && cap)
    f.control = cb, f.controllen = cap > sizeof cb ? (unsigned int) sizeof cb : (unsigned int) cap;
  long r = er(sc3(NR_recvmsg, fd, (long) &f, (long) __love_msgfb(fl)));
  if (r < 0) return r;
  if (m->msg_name) {
    unsigned int n = f.namelen;
    __love_saout(&sa, n);
    memcpy(m->msg_name, &sa, n > m->msg_namelen ? m->msg_namelen : n);
    m->msg_namelen = n; }
  int trunc = 0;
  if (f.control) {
    unsigned long cn = f.controllen, at = 0, bt = 0, cap = m->msg_controllen;
    unsigned long ch = CMSG_ALIGN(sizeof(struct cmsghdr)), bh = __love_cmh(), bal = __love_cma() - 1;
    unsigned char *o = m->msg_control;
    while (bt + 12 <= cn) {
      unsigned long l = *(unsigned int*) (cb + bt), dl = l - bh;
      int lv = *(int*) (cb + bt + 4), ty = *(int*) (cb + bt + 8);
      if (l < bh || l > cn - bt) break;
      if (at + ch + dl > cap) { trunc = 1; break; }
      if (lv == 0xffff) lv = 1;
      if (lv == 41 && ty == 47) ty = 52;  /* IPV6_HOPLIMIT */
      struct cmsghdr *h = (struct cmsghdr*) (o + at);
      h->cmsg_len = ch + dl; h->cmsg_level = lv; h->cmsg_type = ty;
      memcpy(o + at + ch, cb + bt + bh, dl);
      at += CMSG_ALIGN(ch + dl);
      bt += (l + bal) & ~bal; }
    m->msg_controllen = at; }
  else m->msg_controllen = 0;
  m->msg_flags = (int) __love_msgcan(f.flags) | (trunc ? MSG_CTRUNC : 0);
  return r; }
