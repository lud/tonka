hcl = File.read!("var/projects/dev/settings.hcl")
settings = HXL.decode(hcl, functions: %{"file" => &File.read/1})
settings |> IO.inspect(label: "settings")
