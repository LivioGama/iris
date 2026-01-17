#!/bin/bash

# Add public initializers to classes that don't have explicit ones

for file in IRISVision/Sources/*.swift IRISGaze/Sources/*.swift IRISNetwork/Sources/*.swift IRISMedia/Sources/*.swift; do
    # Check if file contains a public class without a public init
    if grep -q "^public class" "$file"; then
        # Check if file doesn't already have a public init
        if ! grep -q "public init()" "$file"; then
            # Find the line number of the class declaration
            class_line=$(grep -n "^public class" "$file" | cut -d: -f1 | head -1)
            if [ -n "$class_line" ]; then
                # Add public init after the class line
                # Find next line after class opening brace
                next_line=$((class_line + 1))

                # Insert public init
                sed -i '' "${next_line}i\\
\\
    public init() {}
" "$file"
                echo "Added public init to $file"
            fi
        fi
    fi
done
