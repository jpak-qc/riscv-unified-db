# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vxsat_roundtrip.S — probe for the vxsat/vxrm CSR self-read fix
#
# These cases failed before the fix (sw_write routed through own VALUE but
# sw_read came from vcsr — two different backing stores). After the fix both
# sw_write and sw_read route through vcsr.
#
# T1: csrw vxsat,1 then csrr vxsat  must return 1
# T2: csrw vxsat,0 then csrr vxsat  must return 0
# T3: csrw vxrm,2  then csrr vxrm   must return 2 (rdn mode)
# T4: write vxrm=1, write vxsat=1, read vxrm — must still be 1 (no cross-contamination)
# T5: write vcsr=0x5 (vxrm=2,vxsat=1), read vxsat — must be 1
# T6: write vcsr=0x5, read vxrm      — must be 2

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  TEST_CASE(1, x2, 0x01, \
    li x4,1; csrw vxsat,x4; csrr x2,vxsat; )

  TEST_CASE(2, x2, 0x00, \
    csrw vxsat,x0; csrr x2,vxsat; )

  TEST_CASE(3, x2, 0x02, \
    li x4,2; csrw vxrm,x4; csrr x2,vxrm; csrw vxrm,x0; )

  TEST_CASE(4, x2, 0x01, \
    li x4,1; csrw vxrm,x4; li x4,1; csrw vxsat,x4; csrr x2,vxrm; csrw vxrm,x0; )

  TEST_CASE(5, x2, 0x01, \
    li x4,5; csrw vcsr,x4; csrr x2,vxsat; )

  TEST_CASE(6, x2, 0x02, \
    li x4,5; csrw vcsr,x4; csrr x2,vxrm; csrw vcsr,x0; )

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
