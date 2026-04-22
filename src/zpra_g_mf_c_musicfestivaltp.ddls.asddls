@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@EndUserText: {
  label: '###GENERATED Core Data Service Entity'
}
@ObjectModel: {
  sapObjectNodeType.name: 'ZPRA_G_MF_A_MF'
}
@AccessControl.authorizationCheck: #MANDATORY
define root view entity ZPRA_G_MF_C_MUSICFESTIVALTP
  provider contract transactional_query
  as projection on ZPRA_G_MF_R_MUSICFESTIVAL
{
  key UUID,
  Title,
  Description,
  EventDateTime,
  MaxVisitorsNumber,
  FreeVisitorSeats,
  @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_G_MF_CALC_MF_ELEMENTS'
  virtual CapacityText : abap.char(20),
  VisitorsFeeAmount,
  @Consumption: {
    valueHelpDefinition: [ {
      entity.element: 'Currency',
      entity.name: 'I_CurrencyStdVH',
      useForValidation: true
    } ]
  }
  VisitorsFeeCurrency,
  @ObjectModel.text.element: ['StatusText']
  Status,
  _Status.Description as StatusText,
  @Semantics: {
    user.createdBy: true
  }
  CreatedBy,
  CreatedAt,
  @Semantics: {
    systemDateTime.lastChangedAt: true
  }
  LastChangedAt,
  @Semantics: {
    systemDateTime.localInstanceLastChangedAt: true
  }
  LocalLastChangedAt,
  @Semantics: {
    user.lastChangedBy: true
  }
  LastChangedBy,
  ProjectID,
  _Visit : redirected to composition child ZPRA_G_MF_C_VISITTP,
  _Status
}
