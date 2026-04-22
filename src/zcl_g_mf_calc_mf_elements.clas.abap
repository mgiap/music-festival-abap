CLASS zcl_g_mf_calc_mf_elements DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

ENDCLASS.

CLASS zcl_g_mf_calc_mf_elements IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~calculate.

    DATA events TYPE STANDARD TABLE OF ZPRA_G_MF_C_MUSICFESTIVALTP WITH DEFAULT KEY.
    events = CORRESPONDING #( it_original_data ).

    LOOP AT events REFERENCE INTO DATA(event).
      LOOP AT it_requested_calc_elements REFERENCE INTO DATA(req_calc_elements).
        CASE req_calc_elements->*.
          WHEN 'CAPACITYTEXT'.
            event->CapacityText = |{ event->FreeVisitorSeats } / { event->MaxVisitorsNumber }|.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( events ).

  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

    CLEAR et_requested_orig_elements.

    IF iv_entity EQ 'ZPRA_G_MF_C_MUSICFESTIVALTP'.
      IF line_exists( it_requested_calc_elements[ table_line = 'CAPACITYTEXT' ] ).
        INSERT |MAXVISITORSNUMBER| INTO TABLE et_requested_orig_elements.
        INSERT |FREEVISITORSEATS|  INTO TABLE et_requested_orig_elements.
      ENDIF.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
