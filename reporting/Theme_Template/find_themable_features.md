[Back to theme template](theme_template.md)

# How to find themable features

In order to find the values that you can include into a visual, do the following steps: 
1) Have one visual in your report and manualy change what you want to include
2) Save the Power BI report as a .pbid file in your preferred location
3) Follow this file path <Power_BI_Report>.Report/definition/pages/<hash_value>/visuals/<hash_value>/visual
4) Open the file and find a "objects" line. Example below is from a slicer:
```json
"objects": {
    "data": [
    {
        "properties": {
        "mode": {
            "expr": {
            "Literal": {
                "Value": "'Dropdown'"
            }
            }
        }
        }
    }
    ],
    "selection": [
    {
        "properties": {
        "strictSingleSelect": {
            "expr": {
            "Literal": {
                "Value": "true"
            }
            }
        }
        }
    }
    ]
}
```

Here we can see that within *objects* there is a property called *selection* that can be added to the theme. Within *selection*, there is a property called *strictSingleSelect* that can be set to a value: *true*. The allowed values vary, but Power BI will display an error when importing the theme template file if the value is invalid.

**Note:** If the property you want to change is wrapped inside a *data*, it cannot be set in the theme. This is because such values can only be set on a specific visual, not globally for all visuals. In the example above, we can see that *mode* = "Dropdown" is not themeable.

Within the theme.json file, it will look something like this:
```json
{
    "visualStyles": {
        "slicer": {
            "*": {
                "selection": [{
                    "strictSingleSelect" : true
                }]
            }
        }
    }
}
```
