package heroku

import (
	"github.com/bgentry/testnet"
	"testing"
)

//
// AppInfo()
//

const appInfoResponseBody = `{
	"archived_at": "2012-01-01T12:00:00Z",
	"buildpack_provided_description": "Ruby/Rack",
	"created_at": "2012-01-01T12:00:00Z",
	"git_url": "git@heroku.com/example.git",
	"id": "01234567-89ab-cdef-0123-456789abcdef",
	"maintenance": true,
	"name": "example",
	"owner": {
		"email": "username@example.com",
		"id": "01234567-89ab-cdef-0123-456789abcdef"
	},
	"region": {
		"id": "01234567-89ab-cdef-0123-456789abcdef",
		"name": "us"
	},
	"released_at": "2012-01-01T12:00:00Z",
	"repo_size": 1,
	"slug_size": 1,
	"stack": {
		"id": "01234567-89ab-cdef-0123-456789abcdef",
		"name": "cedar"
	},
	"updated_at": "2012-01-01T12:00:00Z",
	"web_url": "http://example.herokuapp.com"
}`

var appInfoResponse = testnet.TestResponse{
	Status: 200,
	Body:   appInfoResponseBody,
}
var appInfoRequest = newTestRequest("GET", "/apps/example", "", appInfoResponse)

func TestAppInfoSuccess(t *testing.T) {
	ts, handler, c := newTestServerAndClient(t, appInfoRequest)
	defer ts.Close()

	app, err := c.AppInfo("example")
	if err != nil {
		t.Fatal(err)
	}
	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
	if app == nil {
		t.Fatal("no app object returned")
	}
	testStringsEqual(t, "app.Name", "example", app.Name)
	testStringsEqual(t, "app.Region.Name", "us", app.Region.Name)
	testStringsEqual(t, "app.Stack.Name", "cedar", app.Stack.Name)
	testStringsEqual(t, "app.Owner.Email", "username@example.com", app.Owner.Email)
}

//
// AppList()
//

var appListResponse = testnet.TestResponse{
	Status: 200,
	Body:   "[" + appInfoResponseBody + "]",
}
var appListRequest = newTestRequest("GET", "/apps", "", appListResponse)

func TestAppListSuccess(t *testing.T) {
	appListRequest.Header.Set("Range", "..; max=1")

	ts, handler, c := newTestServerAndClient(t, appListRequest)
	defer ts.Close()

	lr := ListRange{Max: 1}
	apps, err := c.AppList(&lr)
	if err != nil {
		t.Fatal(err)
	}
	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
	if len(apps) != 1 {
		t.Fatalf("expected 1 app, got %d", len(apps))
	}
	app := apps[0]
	testStringsEqual(t, "app.Name", "example", app.Name)
	testStringsEqual(t, "app.Region.Name", "us", app.Region.Name)
	testStringsEqual(t, "app.Stack.Name", "cedar", app.Stack.Name)
	testStringsEqual(t, "app.Owner.Email", "username@example.com", app.Owner.Email)
}

//
// AppCreate()
//

func TestAppCreateSuccess(t *testing.T) {
	appCreateRequestBodies := []string{
		`{}`,
		`{"name":"example"}`,
		`{"region":"us"}`,
		`{"stack":"cedar"}`,
		`{"name":"example", "region":"us", "stack":"cedar"}`,
	}

	nameval := "example"
	regionval := "us"
	stackval := "cedar"
	appCreateRequestOptions := []AppCreateOpts{
		AppCreateOpts{},
		AppCreateOpts{Name: &nameval},
		AppCreateOpts{Region: &regionval},
		AppCreateOpts{Stack: &stackval},
		AppCreateOpts{Name: &nameval, Region: &regionval, Stack: &stackval},
	}

	appCreateResponse := testnet.TestResponse{
		Status: 201,
		Body:   appInfoResponseBody,
	}

	reqs := make([]testnet.TestRequest, len(appCreateRequestBodies))
	for i, body := range appCreateRequestBodies {
		reqs[i] = newTestRequest("POST", "/apps", body, appCreateResponse)
	}

	ts, handler, c := newTestServerAndClient(t, reqs...)
	defer ts.Close()

	for i := range appCreateRequestBodies {
		app, err := c.AppCreate(appCreateRequestOptions[i])
		if err != nil {
			t.Fatal(err)
		}
		if app == nil {
			t.Fatal("no app object returned")
		}
		testStringsEqual(t, "app.Name", "example", app.Name)
		testStringsEqual(t, "app.Region.Name", "us", app.Region.Name)
		testStringsEqual(t, "app.Stack.Name", "cedar", app.Stack.Name)
	}

	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
}

//
// AppDelete()
//

var appDeleteResponse = testnet.TestResponse{
	Status: 200,
	Body:   appInfoResponseBody,
}
var appDeleteRequest = newTestRequest("DELETE", "/apps/example", "", appDeleteResponse)

func TestAppDeleteSuccess(t *testing.T) {
	ts, handler, c := newTestServerAndClient(t, appDeleteRequest)
	defer ts.Close()

	err := c.AppDelete("example")
	if err != nil {
		t.Fatal(err)
	}
	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
}

//
// AppUpdate()
//

func TestAppUpdateSuccess(t *testing.T) {
	appUpdateRequestBodies := []string{
		`{"maintenance":true}`,
		`{"name":"example"}`,
		`{"maintenance":true, "name":"example"}`,
	}

	maintval := true
	nameval := "example"
	appUpdateRequestOptions := []AppUpdateOpts{
		AppUpdateOpts{Maintenance: &maintval},
		AppUpdateOpts{Name: &nameval},
		AppUpdateOpts{Maintenance: &maintval, Name: &nameval},
	}

	appUpdateResponse := testnet.TestResponse{
		Status: 201,
		Body:   appInfoResponseBody,
	}

	reqs := make([]testnet.TestRequest, len(appUpdateRequestBodies))
	for i, body := range appUpdateRequestBodies {
		reqs[i] = newTestRequest("PATCH", "/apps/example", body, appUpdateResponse)
	}

	ts, handler, c := newTestServerAndClient(t, reqs...)
	defer ts.Close()

	for i := range appUpdateRequestBodies {
		app, err := c.AppUpdate("example", appUpdateRequestOptions[i])
		if err != nil {
			t.Fatal(err)
		}
		if app == nil {
			t.Fatal("no app object returned")
		}
		testStringsEqual(t, "app.Name", "example", app.Name)
		testStringsEqual(t, "app.Region.Name", "us", app.Region.Name)
		testStringsEqual(t, "app.Stack.Name", "cedar", app.Stack.Name)
	}

	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
}
