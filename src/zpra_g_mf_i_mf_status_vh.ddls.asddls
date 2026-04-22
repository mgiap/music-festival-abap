@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Music Festival Status VH'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZPRA_G_MF_I_MF_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE( p_domain_name : 'ZPRA_GIAP_MF_STATUS_CODE' ) as Value
  association [0..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _text
    on  Value.domain_name    = _text.domain_name
    and Value.value_position = _text.value_position
    and _text.language       = $session.system_language
{
      @UI.hidden: true
  key Value.domain_name     as Name,
      @UI.hidden: true
  key Value.value_position  as ValuePosition,
      Value.value_low       as Value,
      _text( p_domain_name : 'ZPRA_GIAP_MF_STATUS_CODE' ).text as Description
}
