ifndef MAPSHOT_BUCKET_NAME
$(error MAPSHOT_BUCKET_NAME is not set)
endif

ifndef CLOUDFRONT_DISTRIBUTION_ID
$(error CLOUDFRONT_DISTRIBUTION_ID is not set)
endif

SCRIPT_OUTPUT_DIR := "$(shell factorix path --json | jq -r .script_output_dir)"
MAPSHOT_DIR := "$(SCRIPT_OUTPUT_DIR)/mapshot"
BUCKET := s3://$(MAPSHOT_BUCKET_NAME)
STATIC_FILES := index.html robots.txt

.PHONY: index.html sync

define copy_file
aws s3 cp $(1) "$(BUCKET)/";
aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_DISTRIBUTION_ID) --paths "/$(1)" --output text;
endef

all: index.html sync

index.html:
	./generate-index.rb "$(MAPSHOT_DIR)" > $@

sync:
	$(foreach file, $(STATIC_FILES),$(call copy_file,$(file)))
	aws s3 sync --delete "$(MAPSHOT_DIR)/" "$(BUCKET)/" $(addprefix --exclude , $(STATIC_FILES))

clean:
	$(RM) index.html
