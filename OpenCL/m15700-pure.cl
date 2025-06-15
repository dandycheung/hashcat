/**
 * Author......: See docs/credits.txt
 * License.....: MIT
 */

#ifdef KERNEL_STATIC
#include M2S(INCLUDE_PATH/inc_vendor.h)
#include M2S(INCLUDE_PATH/inc_types.h)
#include M2S(INCLUDE_PATH/inc_platform.cl)
#include M2S(INCLUDE_PATH/inc_common.cl)
#include M2S(INCLUDE_PATH/inc_hash_sha256.cl)
#include M2S(INCLUDE_PATH/inc_hash_scrypt.cl)
#endif

#define COMPARE_S M2S(INCLUDE_PATH/inc_comp_single.cl)
#define COMPARE_M M2S(INCLUDE_PATH/inc_comp_multi.cl)

typedef struct
{
  #ifndef SCRYPT_TMP_ELEM
  #define SCRYPT_TMP_ELEM 1
  #endif

  uint4 P[SCRYPT_TMP_ELEM];

} scrypt_tmp_t;

typedef struct ethereum_scrypt
{
  u32 salt_buf[16];
  u32 ciphertext[8];

} ethereum_scrypt_t;

#ifndef KECCAK_ROUNDS
#define KECCAK_ROUNDS 24
#endif

#define Theta1(s) (st[0 + s] ^ st[5 + s] ^ st[10 + s] ^ st[15 + s] ^ st[20 + s])

#define Theta2(s)               \
{                               \
  st[ 0 + s] ^= t;              \
  st[ 5 + s] ^= t;              \
  st[10 + s] ^= t;              \
  st[15 + s] ^= t;              \
  st[20 + s] ^= t;              \
}

#define Rho_Pi(s)               \
{                               \
  u32 j = keccakf_piln[s];      \
  u32 k = keccakf_rotc[s];      \
  bc0 = st[j];                  \
  st[j] = hc_rotl64_S (t, k);   \
  t = bc0;                      \
}

#define Chi(s)                  \
{                               \
  bc0 = st[0 + s];              \
  bc1 = st[1 + s];              \
  bc2 = st[2 + s];              \
  bc3 = st[3 + s];              \
  bc4 = st[4 + s];              \
  st[0 + s] ^= ~bc1 & bc2;      \
  st[1 + s] ^= ~bc2 & bc3;      \
  st[2 + s] ^= ~bc3 & bc4;      \
  st[3 + s] ^= ~bc4 & bc0;      \
  st[4 + s] ^= ~bc0 & bc1;      \
}

CONSTANT_VK u64a keccakf_rndc[24] =
{
  KECCAK_RNDC_00, KECCAK_RNDC_01, KECCAK_RNDC_02, KECCAK_RNDC_03,
  KECCAK_RNDC_04, KECCAK_RNDC_05, KECCAK_RNDC_06, KECCAK_RNDC_07,
  KECCAK_RNDC_08, KECCAK_RNDC_09, KECCAK_RNDC_10, KECCAK_RNDC_11,
  KECCAK_RNDC_12, KECCAK_RNDC_13, KECCAK_RNDC_14, KECCAK_RNDC_15,
  KECCAK_RNDC_16, KECCAK_RNDC_17, KECCAK_RNDC_18, KECCAK_RNDC_19,
  KECCAK_RNDC_20, KECCAK_RNDC_21, KECCAK_RNDC_22, KECCAK_RNDC_23
};

DECLSPEC void keccak_transform_S (PRIVATE_AS u64 *st)
{
  const u8 keccakf_rotc[24] =
  {
     1,  3,  6, 10, 15, 21, 28, 36, 45, 55,  2, 14,
    27, 41, 56,  8, 25, 43, 62, 18, 39, 61, 20, 44
  };

  const u8 keccakf_piln[24] =
  {
    10,  7, 11, 17, 18,  3,  5, 16,  8, 21, 24,  4,
    15, 23, 19, 13, 12,  2, 20, 14, 22,  9,  6,  1
  };

  /**
   * Keccak
   */

  int round;

  for (round = 0; round < KECCAK_ROUNDS; round++)
  {
    // Theta

    u64 bc0 = Theta1 (0);
    u64 bc1 = Theta1 (1);
    u64 bc2 = Theta1 (2);
    u64 bc3 = Theta1 (3);
    u64 bc4 = Theta1 (4);

    u64 t;

    t = bc4 ^ hc_rotl64_S (bc1, 1); Theta2 (0);
    t = bc0 ^ hc_rotl64_S (bc2, 1); Theta2 (1);
    t = bc1 ^ hc_rotl64_S (bc3, 1); Theta2 (2);
    t = bc2 ^ hc_rotl64_S (bc4, 1); Theta2 (3);
    t = bc3 ^ hc_rotl64_S (bc0, 1); Theta2 (4);

    // Rho Pi

    t = st[1];

    Rho_Pi (0);
    Rho_Pi (1);
    Rho_Pi (2);
    Rho_Pi (3);
    Rho_Pi (4);
    Rho_Pi (5);
    Rho_Pi (6);
    Rho_Pi (7);
    Rho_Pi (8);
    Rho_Pi (9);
    Rho_Pi (10);
    Rho_Pi (11);
    Rho_Pi (12);
    Rho_Pi (13);
    Rho_Pi (14);
    Rho_Pi (15);
    Rho_Pi (16);
    Rho_Pi (17);
    Rho_Pi (18);
    Rho_Pi (19);
    Rho_Pi (20);
    Rho_Pi (21);
    Rho_Pi (22);
    Rho_Pi (23);

    //  Chi

    Chi (0);
    Chi (5);
    Chi (10);
    Chi (15);
    Chi (20);

    //  Iota

    st[0] ^= keccakf_rndc[round];
  }
}

KERNEL_FQ void HC_ATTR_SEQ m15700_init (KERN_ATTR_TMPS_ESALT (scrypt_tmp_t, ethereum_scrypt_t))
{
  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  scrypt_pbkdf2 (pws[gid].i, pws[gid].pw_len, salt_bufs[SALT_POS_HOST].salt_buf, salt_bufs[SALT_POS_HOST].salt_len, tmps[gid].P, SCRYPT_CNT * 4);

  scrypt_blockmix_in (tmps[gid].P, SCRYPT_CNT * 4);
}

KERNEL_FQ void HC_ATTR_SEQ m15700_loop_prepare (KERN_ATTR_TMPS (scrypt_tmp_t))
{
  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);

  if (gid >= GID_CNT) return;

  GLOBAL_AS uint4 *d_scrypt0_buf = (GLOBAL_AS uint4 *) d_extra0_buf;
  GLOBAL_AS uint4 *d_scrypt1_buf = (GLOBAL_AS uint4 *) d_extra1_buf;
  GLOBAL_AS uint4 *d_scrypt2_buf = (GLOBAL_AS uint4 *) d_extra2_buf;
  GLOBAL_AS uint4 *d_scrypt3_buf = (GLOBAL_AS uint4 *) d_extra3_buf;

  #ifdef IS_HIP
  LOCAL_VK uint4 X_s[MAX_THREADS_PER_BLOCK][STATE_CNT4];
  LOCAL_AS uint4 *X = X_s[lid];
  #else
  uint4 X[STATE_CNT4];
  #endif

  const u32 P_offset = SALT_REPEAT * STATE_CNT4;

  GLOBAL_AS uint4 *P = tmps[gid].P + P_offset;

  for (int z = 0; z < STATE_CNT4; z++) X[z] = P[z];

  scrypt_smix_init (X, d_scrypt0_buf, d_scrypt1_buf, d_scrypt2_buf, d_scrypt3_buf, gid);

  for (int z = 0; z < STATE_CNT4; z++) P[z] = X[z];
}

KERNEL_FQ void HC_ATTR_SEQ m15700_loop (KERN_ATTR_TMPS (scrypt_tmp_t))
{
  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);

  if (gid >= GID_CNT) return;

  GLOBAL_AS uint4 *d_scrypt0_buf = (GLOBAL_AS uint4 *) d_extra0_buf;
  GLOBAL_AS uint4 *d_scrypt1_buf = (GLOBAL_AS uint4 *) d_extra1_buf;
  GLOBAL_AS uint4 *d_scrypt2_buf = (GLOBAL_AS uint4 *) d_extra2_buf;
  GLOBAL_AS uint4 *d_scrypt3_buf = (GLOBAL_AS uint4 *) d_extra3_buf;

  uint4 X[STATE_CNT4];

  #ifdef IS_HIP
  LOCAL_VK uint4 T_s[MAX_THREADS_PER_BLOCK][STATE_CNT4];
  LOCAL_AS uint4 *T = T_s[lid];
  #else
  uint4 T[STATE_CNT4];
  #endif

  const u32 P_offset = SALT_REPEAT * STATE_CNT4;

  GLOBAL_AS uint4 *P = tmps[gid].P + P_offset;

  for (int z = 0; z < STATE_CNT4; z++) X[z] = P[z];

  scrypt_smix_loop (X, T, d_scrypt0_buf, d_scrypt1_buf, d_scrypt2_buf, d_scrypt3_buf, gid);

  for (int z = 0; z < STATE_CNT4; z++) P[z] = X[z];
}

KERNEL_FQ void HC_ATTR_SEQ m15700_comp (KERN_ATTR_TMPS_ESALT (scrypt_tmp_t, ethereum_scrypt_t))
{
  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  scrypt_blockmix_out (tmps[gid].P, SCRYPT_CNT * 4);

  scrypt_pbkdf2 (pws[gid].i, pws[gid].pw_len, (GLOBAL_AS const u32 *) tmps[gid].P, SCRYPT_CNT * 4, tmps[gid].P, 32);

  /**
   * keccak
   */

  u32 ciphertext[8];

  ciphertext[0] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[0];
  ciphertext[1] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[1];
  ciphertext[2] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[2];
  ciphertext[3] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[3];
  ciphertext[4] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[4];
  ciphertext[5] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[5];
  ciphertext[6] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[6];
  ciphertext[7] = esalt_bufs[DIGESTS_OFFSET_HOST].ciphertext[7];

  u32 key[4];

  key[0] = tmps[gid].P[1].x;
  key[1] = tmps[gid].P[1].y;
  key[2] = tmps[gid].P[1].z;
  key[3] = tmps[gid].P[1].w;

  u64 st[25];

  st[ 0] = hl32_to_64_S (key[1], key[0]);
  st[ 1] = hl32_to_64_S (key[3], key[2]);
  st[ 2] = hl32_to_64_S (ciphertext[1], ciphertext[0]);
  st[ 3] = hl32_to_64_S (ciphertext[3], ciphertext[2]);
  st[ 4] = hl32_to_64_S (ciphertext[5], ciphertext[4]);
  st[ 5] = hl32_to_64_S (ciphertext[7], ciphertext[6]);
  st[ 6] = 0x01;
  st[ 7] = 0;
  st[ 8] = 0;
  st[ 9] = 0;
  st[10] = 0;
  st[11] = 0;
  st[12] = 0;
  st[13] = 0;
  st[14] = 0;
  st[15] = 0;
  st[16] = 0;
  st[17] = 0;
  st[18] = 0;
  st[19] = 0;
  st[20] = 0;
  st[21] = 0;
  st[22] = 0;
  st[23] = 0;
  st[24] = 0;

  const u32 mdlen = 32;

  const u32 rsiz = 200 - (2 * mdlen);

  const u32 add80w = (rsiz - 1) / 8;

  st[add80w] |= 0x8000000000000000UL;

  keccak_transform_S (st);

  const u32 r0 = l32_from_64_S (st[0]);
  const u32 r1 = h32_from_64_S (st[0]);
  const u32 r2 = l32_from_64_S (st[1]);
  const u32 r3 = h32_from_64_S (st[1]);

  #define il_pos 0

  #ifdef KERNEL_STATIC
  #include COMPARE_M
  #endif
}
