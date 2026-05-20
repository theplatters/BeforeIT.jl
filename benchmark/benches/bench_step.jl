setup_for_step() = BeforeIT.AUSTRIA2010Q1 |> BeforeIT.ECSModel
SUITE["step"] = @be setup_for_step() BeforeIT.step!(_)
