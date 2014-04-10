module TimestampHelpers

  # Returns the updated date that should be presented to the user
  def presented_updated_date(artefact)
    # Use the latest updated_at of the artefact or edition
    updated_options = [artefact.updated_at]
    updated_options << artefact.edition.updated_at if artefact.edition
    updated_options.compact.max
  end
  
  # Returns the created date that should be presented to the user
  def presented_created_date(artefact)
    artefact.created_at
  end
end
