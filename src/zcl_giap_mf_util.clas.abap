CLASS zcl_giap_mf_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS generate_sample_data.

ENDCLASS.



CLASS zcl_giap_mf_util IMPLEMENTATION.

  METHOD generate_sample_data.

      DATA ls_festival TYPE zpra_g_mf_a_mf.

      TRY.
          ls_festival-client = sy-mandt.
          ls_festival-uuid   = cl_system_uuid=>create_uuid_x16_static( ).
          ls_festival-title  = 'Test Festival'.
          ls_festival-status = 'P'.

          INSERT zpra_g_mf_a_mf FROM @ls_festival.

        CATCH cx_uuid_error.
          " Do nothing (or add a simple message later)
      ENDTRY.

    ENDMETHOD.

ENDCLASS.
