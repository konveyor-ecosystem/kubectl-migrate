.PHONY: resources-deploy resources-destroy help

# Deploy sample applications
# Usage: make resources-deploy [app1 app2 ...]
# Example: make resources-deploy hello-world
# Example: make resources-deploy hello-world another-app
# If no arguments provided, deploys all applications
resources-deploy:
	@if [ "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		for app in $(filter-out $@,$(MAKECMDGOALS)); do \
			echo "Deploying sample application: $$app..."; \
			if [ -d "sample-resources/$$app" ]; then \
				if [ -f "sample-resources/$$app/deploy.sh" ]; then \
					(cd "sample-resources/$$app" && ./deploy.sh); \
					echo "Application $$app deployed successfully!"; \
				else \
					echo "Error: deploy.sh not found in sample-resources/$$app"; \
					exit 1; \
				fi; \
			else \
				echo "Error: Directory sample-resources/$$app does not exist"; \
				exit 1; \
			fi; \
		done \
	else \
		echo "Deploying all sample applications..."; \
		for dir in sample-resources/*/; do \
			if [ -f "$$dir/deploy.sh" ]; then \
				echo "Deploying $$dir..."; \
				(cd "$$dir" && ./deploy.sh); \
			fi \
		done; \
		echo "All applications deployed successfully!"; \
	fi

# Catch-all target to prevent "No rule to make target" errors for app names
%:
	@:

# Destroy sample applications
# Usage: make resources-destroy [app1 app2 ...]
# Example: make resources-destroy hello-world
# Example: make resources-destroy hello-world another-app
# If no arguments provided, destroys all applications
resources-destroy:
	@if [ "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		for app in $(filter-out $@,$(MAKECMDGOALS)); do \
			echo "Destroying sample application: $$app..."; \
			if [ -d "sample-resources/$$app" ]; then \
				if [ -f "sample-resources/$$app/destroy.sh" ]; then \
					(cd "sample-resources/$$app" && ./destroy.sh); \
					echo "Application $$app destroyed successfully!"; \
				else \
					echo "Error: destroy.sh not found in sample-resources/$$app"; \
					exit 1; \
				fi; \
			else \
				echo "Error: Directory sample-resources/$$app does not exist"; \
				exit 1; \
			fi; \
		done \
	else \
		echo "Destroying all sample applications..."; \
		for dir in sample-resources/*/; do \
			if [ -f "$$dir/destroy.sh" ]; then \
				echo "Destroying $$dir..."; \
				(cd "$$dir" && ./destroy.sh); \
			fi \
		done; \
		echo "All applications destroyed successfully!"; \
	fi

# Show help
help:
	@echo "Available targets:"
	@echo "  resources-deploy [app1 app2 ...]  - Deploy sample application(s) to Kubernetes cluster"
	@echo "                                      If app names are specified, deploy only those applications"
	@echo "                                      If no app names specified, deploy all applications"
	@echo "                                      Example: make resources-deploy hello-world"
	@echo "  resources-destroy [app1 app2 ...] - Remove sample application(s) from Kubernetes cluster"
	@echo "                                      If app names are specified, destroy only those applications"
	@echo "                                      If no app names specified, destroy all applications"
	@echo "                                      Example: make resources-destroy hello-world"
	@echo "  help                              - Show this help message"
