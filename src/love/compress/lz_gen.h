// lz_gen.h -- laid by src/love/compress/lz.l, `make mx`. edit that file.
static int lz_run(struct lz_model *m, struct lz_rd *r, struct lz_out *o, uintptr_t lim, int eopm) {
 uint8_t const *inb = r->p;
 uint8_t *ob = o->b;
 lzp *P = (lzp *) m, *L = m->lit;
 uintptr_t i = r->i, nin = r->n, rg = r->range, cd = r->code, on = o->n, cap = o->cap, base = o->base, st = m->state, r0 = m->reps[0], litn = (uintptr_t) 768 << (m->lc + m->lp), lpm = ((uintptr_t) 1 << m->lp) - 1, pbm = ((uintptr_t) 1 << m->pb) - 1, lc = m->lc, pz = o->pause, bd = r->bad, em = eopm, hlim, top, b, pw, q, k, t, t0, ps, sx, li, pv, mb, mbit, off, sy, len, lv, tv, bx, lx, sb, slot, d, fb, nd, v, rm, ix, j, kind, sh, ck, zm1, zm2, zm3, zm4, zm5, zm6, zm7, zm8;
 int rc = 1;
 if (bd) {
  i = nin + 1;
 }
 if (em) {
  lim = ~0;
 }
 hlim = lim;
 if (pz) {
  if (cap < 273)
   return 0;
  if (cap - 273 < lim) {
   lim = cap - 273;
  }
  if (cap < hlim) {
   hlim = cap;
  }
 }
 top = cap;
 if (hlim < top) {
  top = hlim;
 }
 while (on < lim) {
  t0 = on & pbm;
  ps = t0 & 15;
  if (nin < i) {
   rc = 0;
   break;
  }
  if (pz == 1) {
   if (nin - i < 20) {
    rc = 3;
    break;
   }
  }
  sx = (st << 4) + ps;
  if (rg < 16777216) {
   rg = rg << 8;
   if (i < nin) {
    cd = cd << 8 | inb[i];
    i++;
   } else {
    cd = cd << 8;
    i = nin + 1;
   }
  }
  pw = P[sx];
  q = (rg >> 11) * pw;
  if (cd < q) {
   rg = q;
   P[sx] = (uint16_t) (pw + ((2048 - pw) >> 5));
   b = 0;
  } else {
   rg = rg - q;
   cd = cd - q;
   P[sx] = (uint16_t) (pw - (pw >> 5));
   b = 1;
  }
  if (!b) {
   if (cap <= on) {
    rc = 0;
    break;
   }
   if (base < on) {
    pv = ob[on - 1];
   } else {
    pv = 0;
   }
   li = 768 * (((on & lpm) << lc) + (pv >> (8 - lc)));
   if (litn - 768 < li) {
    rc = 0;
    break;
   }
   if (7 <= st) {
    if (on - base <= r0) {
     rc = 0;
     break;
    }
    mb = ob[on - r0 - 1];
    sy = 1;
    off = 256;
    while (sy < 256) {
     mb = mb << 1;
     mbit = mb & off;
     ix = li + (off + mbit) + sy;
     if (litn <= ix) {
      rc = 0;
      break;
     }
     if (rg < 16777216) {
      rg = rg << 8;
      if (i < nin) {
       cd = cd << 8 | inb[i];
       i++;
      } else {
       cd = cd << 8;
       i = nin + 1;
      }
     }
     pw = L[ix];
     q = (rg >> 11) * pw;
     k = LZ_LT(cd, q);
     t = k + 1;
     b = t & 1;
     rg = q + ((rg - q - q) & ~k);
     cd = cd - (q & ~k);
     L[ix] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
     sy = sy << 1 | b;
     off = off & ((0 - b) ^ ~mbit);
    }
   } else {
    zm1 = 1;
    while (zm1 < 256) {
     if (rg < 16777216) {
      rg = rg << 8;
      if (i < nin) {
       cd = cd << 8 | inb[i];
       i++;
      } else {
       cd = cd << 8;
       i = nin + 1;
      }
     }
     pw = L[li + zm1];
     q = (rg >> 11) * pw;
     k = LZ_LT(cd, q);
     t = k + 1;
     b = t & 1;
     rg = q + ((rg - q - q) & ~k);
     cd = cd - (q & ~k);
     L[li + zm1] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
     zm1 = zm1 << 1 | b;
    }
    sy = zm1 - 256;
   }
   ob[on] = (uint8_t) sy;
   on++;
   if (st < 4) {
    st = 0;
   } else {
    if (st < 10) {
     st = st - 3;
    } else {
     st = st - 6;
    }
   }
  } else {
   if (rg < 16777216) {
    rg = rg << 8;
    if (i < nin) {
     cd = cd << 8 | inb[i];
     i++;
    } else {
     cd = cd << 8;
     i = nin + 1;
    }
   }
   pw = P[st + 192];
   q = (rg >> 11) * pw;
   if (cd < q) {
    rg = q;
    P[st + 192] = (uint16_t) (pw + ((2048 - pw) >> 5));
    b = 0;
   } else {
    rg = rg - q;
    cd = cd - q;
    P[st + 192] = (uint16_t) (pw - (pw >> 5));
    b = 1;
   }
   if (!b) {
    if (rg < 16777216) {
     rg = rg << 8;
     if (i < nin) {
      cd = cd << 8 | inb[i];
      i++;
     } else {
      cd = cd << 8;
      i = nin + 1;
     }
    }
    pw = P[818];
    q = (rg >> 11) * pw;
    if (cd < q) {
     rg = q;
     P[818] = (uint16_t) (pw + ((2048 - pw) >> 5));
     b = 0;
    } else {
     rg = rg - q;
     cd = cd - q;
     P[818] = (uint16_t) (pw - (pw >> 5));
     b = 1;
    }
    if (!b) {
     bx = (ps << 3) + 820;
     zm2 = 1;
     while (zm2 < 8) {
      if (rg < 16777216) {
       rg = rg << 8;
       if (i < nin) {
        cd = cd << 8 | inb[i];
        i++;
       } else {
        cd = cd << 8;
        i = nin + 1;
       }
      }
      pw = P[bx + zm2];
      q = (rg >> 11) * pw;
      k = LZ_LT(cd, q);
      t = k + 1;
      b = t & 1;
      rg = q + ((rg - q - q) & ~k);
      cd = cd - (q & ~k);
      P[bx + zm2] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
      zm2 = zm2 << 1 | b;
     }
     tv = zm2 - 8;
     lv = tv;
    } else {
     if (rg < 16777216) {
      rg = rg << 8;
      if (i < nin) {
       cd = cd << 8 | inb[i];
       i++;
      } else {
       cd = cd << 8;
       i = nin + 1;
      }
     }
     pw = P[819];
     q = (rg >> 11) * pw;
     if (cd < q) {
      rg = q;
      P[819] = (uint16_t) (pw + ((2048 - pw) >> 5));
      b = 0;
     } else {
      rg = rg - q;
      cd = cd - q;
      P[819] = (uint16_t) (pw - (pw >> 5));
      b = 1;
     }
     if (!b) {
      bx = (ps << 3) + 948;
      zm3 = 1;
      while (zm3 < 8) {
       if (rg < 16777216) {
        rg = rg << 8;
        if (i < nin) {
         cd = cd << 8 | inb[i];
         i++;
        } else {
         cd = cd << 8;
         i = nin + 1;
        }
       }
       pw = P[bx + zm3];
       q = (rg >> 11) * pw;
       k = LZ_LT(cd, q);
       t = k + 1;
       b = t & 1;
       rg = q + ((rg - q - q) & ~k);
       cd = cd - (q & ~k);
       P[bx + zm3] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
       zm3 = zm3 << 1 | b;
      }
      tv = zm3 - 8;
      lv = tv + 8;
     } else {
      zm4 = 1;
      while (zm4 < 256) {
       if (rg < 16777216) {
        rg = rg << 8;
        if (i < nin) {
         cd = cd << 8 | inb[i];
         i++;
        } else {
         cd = cd << 8;
         i = nin + 1;
        }
       }
       pw = P[1076 + zm4];
       q = (rg >> 11) * pw;
       k = LZ_LT(cd, q);
       t = k + 1;
       b = t & 1;
       rg = q + ((rg - q - q) & ~k);
       cd = cd - (q & ~k);
       P[1076 + zm4] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
       zm4 = zm4 << 1 | b;
      }
      tv = zm4 - 256;
      lv = tv + 16;
     }
    }
    len = lv + 2;
    kind = 0;
    if (lv < 3) {
     lx = lv;
    } else {
     lx = 3;
    }
    sb = 432 + (lx << 6);
    if (624 < sb) {
     rc = 0;
     break;
    }
    zm5 = 1;
    while (zm5 < 64) {
     if (rg < 16777216) {
      rg = rg << 8;
      if (i < nin) {
       cd = cd << 8 | inb[i];
       i++;
      } else {
       cd = cd << 8;
       i = nin + 1;
      }
     }
     pw = P[sb + zm5];
     q = (rg >> 11) * pw;
     k = LZ_LT(cd, q);
     t = k + 1;
     b = t & 1;
     rg = q + ((rg - q - q) & ~k);
     cd = cd - (q & ~k);
     P[sb + zm5] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
     zm5 = zm5 << 1 | b;
    }
    slot = zm5 - 64;
    if (slot < 4) {
     d = slot;
    } else {
     fb = (slot >> 1) - 1;
     d = (2 | (slot & 1)) << fb;
     if (slot < 14) {
      bx = 688 + d - slot - 1;
      rm = 1;
      v = 0;
      for (j = 0; j < fb; j++) {
       ix = bx + rm;
       if (1846 <= ix) {
        rc = 0;
        break;
       }
       if (rg < 16777216) {
        rg = rg << 8;
        if (i < nin) {
         cd = cd << 8 | inb[i];
         i++;
        } else {
         cd = cd << 8;
         i = nin + 1;
        }
       }
       pw = P[ix];
       q = (rg >> 11) * pw;
       k = LZ_LT(cd, q);
       t = k + 1;
       b = t & 1;
       rg = q + ((rg - q - q) & ~k);
       cd = cd - (q & ~k);
       P[ix] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
       rm = rm << 1 | b;
       v = v | b << j;
      }
      d = d + v;
     } else {
      nd = fb - 4;
      v = 0;
      for (j = 0; j < nd; j++) {
       if (rg < 16777216) {
        rg = rg << 8;
        if (i < nin) {
         cd = cd << 8 | inb[i];
         i++;
        } else {
         cd = cd << 8;
         i = nin + 1;
        }
       }
       rg = rg >> 1;
       t = cd >= rg;
       cd = cd - (rg & (0 - t));
       v = v << 1 | t;
      }
      d = d + (v << 4);
      rm = 1;
      v = 0;
      for (j = 0; j < 4; j++) {
       ix = 802 + rm;
       if (1846 <= ix) {
        rc = 0;
        break;
       }
       if (rg < 16777216) {
        rg = rg << 8;
        if (i < nin) {
         cd = cd << 8 | inb[i];
         i++;
        } else {
         cd = cd << 8;
         i = nin + 1;
        }
       }
       pw = P[ix];
       q = (rg >> 11) * pw;
       k = LZ_LT(cd, q);
       t = k + 1;
       b = t & 1;
       rg = q + ((rg - q - q) & ~k);
       cd = cd - (q & ~k);
       P[ix] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
       rm = rm << 1 | b;
       v = v | b << j;
      }
      d = d + v;
     }
    }
    if (d == 4294967295) {
     if (em) {
      if (i <= nin) {
       rc = 2;
      } else {
       rc = 0;
      }
     } else {
      rc = 0;
     }
     break;
    }
    m->reps[3] = m->reps[2];
    m->reps[2] = m->reps[1];
    m->reps[1] = (uint32_t) r0;
    r0 = d;
   } else {
    if (rg < 16777216) {
     rg = rg << 8;
     if (i < nin) {
      cd = cd << 8 | inb[i];
      i++;
     } else {
      cd = cd << 8;
      i = nin + 1;
     }
    }
    pw = P[st + 204];
    q = (rg >> 11) * pw;
    if (cd < q) {
     rg = q;
     P[st + 204] = (uint16_t) (pw + ((2048 - pw) >> 5));
     b = 0;
    } else {
     rg = rg - q;
     cd = cd - q;
     P[st + 204] = (uint16_t) (pw - (pw >> 5));
     b = 1;
    }
    if (!b) {
     if (rg < 16777216) {
      rg = rg << 8;
      if (i < nin) {
       cd = cd << 8 | inb[i];
       i++;
      } else {
       cd = cd << 8;
       i = nin + 1;
      }
     }
     pw = P[sx + 240];
     q = (rg >> 11) * pw;
     if (cd < q) {
      rg = q;
      P[sx + 240] = (uint16_t) (pw + ((2048 - pw) >> 5));
      b = 0;
     } else {
      rg = rg - q;
      cd = cd - q;
      P[sx + 240] = (uint16_t) (pw - (pw >> 5));
      b = 1;
     }
     if (!b) {
      sh = 1;
     } else {
      sh = 0;
     }
    } else {
     sh = 0;
     if (rg < 16777216) {
      rg = rg << 8;
      if (i < nin) {
       cd = cd << 8 | inb[i];
       i++;
      } else {
       cd = cd << 8;
       i = nin + 1;
      }
     }
     pw = P[st + 216];
     q = (rg >> 11) * pw;
     if (cd < q) {
      rg = q;
      P[st + 216] = (uint16_t) (pw + ((2048 - pw) >> 5));
      b = 0;
     } else {
      rg = rg - q;
      cd = cd - q;
      P[st + 216] = (uint16_t) (pw - (pw >> 5));
      b = 1;
     }
     if (!b) {
      d = m->reps[1];
     } else {
      if (rg < 16777216) {
       rg = rg << 8;
       if (i < nin) {
        cd = cd << 8 | inb[i];
        i++;
       } else {
        cd = cd << 8;
        i = nin + 1;
       }
      }
      pw = P[st + 228];
      q = (rg >> 11) * pw;
      if (cd < q) {
       rg = q;
       P[st + 228] = (uint16_t) (pw + ((2048 - pw) >> 5));
       b = 0;
      } else {
       rg = rg - q;
       cd = cd - q;
       P[st + 228] = (uint16_t) (pw - (pw >> 5));
       b = 1;
      }
      if (!b) {
       d = m->reps[2];
      } else {
       d = m->reps[3];
       m->reps[3] = m->reps[2];
      }
      m->reps[2] = m->reps[1];
     }
     m->reps[1] = (uint32_t) r0;
     r0 = d;
    }
    if (!sh) {
     if (rg < 16777216) {
      rg = rg << 8;
      if (i < nin) {
       cd = cd << 8 | inb[i];
       i++;
      } else {
       cd = cd << 8;
       i = nin + 1;
      }
     }
     pw = P[1332];
     q = (rg >> 11) * pw;
     if (cd < q) {
      rg = q;
      P[1332] = (uint16_t) (pw + ((2048 - pw) >> 5));
      b = 0;
     } else {
      rg = rg - q;
      cd = cd - q;
      P[1332] = (uint16_t) (pw - (pw >> 5));
      b = 1;
     }
     if (!b) {
      bx = (ps << 3) + 1334;
      zm6 = 1;
      while (zm6 < 8) {
       if (rg < 16777216) {
        rg = rg << 8;
        if (i < nin) {
         cd = cd << 8 | inb[i];
         i++;
        } else {
         cd = cd << 8;
         i = nin + 1;
        }
       }
       pw = P[bx + zm6];
       q = (rg >> 11) * pw;
       k = LZ_LT(cd, q);
       t = k + 1;
       b = t & 1;
       rg = q + ((rg - q - q) & ~k);
       cd = cd - (q & ~k);
       P[bx + zm6] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
       zm6 = zm6 << 1 | b;
      }
      tv = zm6 - 8;
      lv = tv;
     } else {
      if (rg < 16777216) {
       rg = rg << 8;
       if (i < nin) {
        cd = cd << 8 | inb[i];
        i++;
       } else {
        cd = cd << 8;
        i = nin + 1;
       }
      }
      pw = P[1333];
      q = (rg >> 11) * pw;
      if (cd < q) {
       rg = q;
       P[1333] = (uint16_t) (pw + ((2048 - pw) >> 5));
       b = 0;
      } else {
       rg = rg - q;
       cd = cd - q;
       P[1333] = (uint16_t) (pw - (pw >> 5));
       b = 1;
      }
      if (!b) {
       bx = (ps << 3) + 1462;
       zm7 = 1;
       while (zm7 < 8) {
        if (rg < 16777216) {
         rg = rg << 8;
         if (i < nin) {
          cd = cd << 8 | inb[i];
          i++;
         } else {
          cd = cd << 8;
          i = nin + 1;
         }
        }
        pw = P[bx + zm7];
        q = (rg >> 11) * pw;
        k = LZ_LT(cd, q);
        t = k + 1;
        b = t & 1;
        rg = q + ((rg - q - q) & ~k);
        cd = cd - (q & ~k);
        P[bx + zm7] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
        zm7 = zm7 << 1 | b;
       }
       tv = zm7 - 8;
       lv = tv + 8;
      } else {
       zm8 = 1;
       while (zm8 < 256) {
        if (rg < 16777216) {
         rg = rg << 8;
         if (i < nin) {
          cd = cd << 8 | inb[i];
          i++;
         } else {
          cd = cd << 8;
          i = nin + 1;
         }
        }
        pw = P[1590 + zm8];
        q = (rg >> 11) * pw;
        k = LZ_LT(cd, q);
        t = k + 1;
        b = t & 1;
        rg = q + ((rg - q - q) & ~k);
        cd = cd - (q & ~k);
        P[1590 + zm8] = (uint16_t) (pw + (((2048 - pw) >> 5) & k) - ((pw >> 5) & ~k));
        zm8 = zm8 << 1 | b;
       }
       tv = zm8 - 256;
       lv = tv + 16;
      }
     }
     len = lv + 2;
     kind = 1;
    } else {
     len = 1;
     kind = 2;
    }
   }
   if (on - base <= r0) {
    rc = 0;
    break;
   }
   if (nin < i) {
    rc = 0;
    break;
   }
   if (top < on) {
    rc = 0;
    break;
   }
   if (top - on < len) {
    rc = 0;
    break;
   }
   if (wideld && 8 <= r0 + 1) {
    if (len + 8 <= cap - on) {
     ck = 0;
     while (ck < len) {
      ST64(ob + (on + ck), LD64(ob + (on + ck - (r0 + 1))));
      ck += 8;
     }
    } else {
     ck = 0;
     while (ck < len) {
      ob[on + ck] = ob[on + ck - (r0 + 1)];
      ck++;
     }
    }
   } else {
    ck = 0;
    while (ck < len) {
     ob[on + ck] = ob[on + ck - (r0 + 1)];
     ck++;
    }
   }
   on += len;
   if (st < 7) {
    st = 7 + kind;
   } else {
    if (!kind) {
     st = 10;
    } else {
     st = 11;
    }
   }
  }
 }
 r->range = (uint32_t) rg;
 r->code = (uint32_t) cd;
 r->bad = nin < i;
 r->i = nin < i ? nin : i;
 m->state = (unsigned int) st;
 m->reps[0] = (uint32_t) r0;
 o->n = on;
 return rc;
}
